//
//  AppDelegate.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Cocoa
import MetalKit
import AudioToolbox

func bridge<T : AnyObject>(obj : T) -> UnsafePointer<Void> {
	return UnsafePointer(Unmanaged.passUnretained(obj).toOpaque())
	// return unsafeAddressOf(obj) // ***
}

func bridge<T : AnyObject>(ptr : UnsafePointer<Void>) -> T {
	return Unmanaged<T>.fromOpaque(COpaquePointer(ptr)).takeUnretainedValue()
	// return unsafeBitCast(ptr, T.self) // ***
}

var count = 0;

func outputCallback(data: UnsafeMutablePointer<Void>, inAudioQueue: AudioQueueRef, inBuffer: AudioQueueBufferRef) {
	let apu: APU = bridge(UnsafePointer<Void>(data));
	
	apu.buffer.loadBuffer(inBuffer);
	
	AudioQueueEnqueueBuffer(inAudioQueue, inBuffer, 0, nil);
}

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate, MTKViewDelegate {

    @IBOutlet weak var window: DisplayWindow!
	
	@IBOutlet weak var metalView: MTKView!
	
	private var device: MTLDevice!;
	private var commandQueue: MTLCommandQueue! = nil
	private var pipeline: MTLComputePipelineState! = nil
	
	var sizingRect: NSRect? = nil;
	
	var textureDescriptor: MTLTextureDescriptor? = nil;
	
	private var texture: MTLTexture! = nil;
	
	private let threadGroupCount = MTLSizeMake(8, 8, 1);
	private var threadGroups: MTLSize?;
	
	private var textureLoader: MTKTextureLoader?;
	
	private let controllerIO: ControllerIO;
	private var cpu: CPU?;
	private var ppu: PPU?;
	private var apu: APU?;
	private let logger: Logger?;
	
	private var frameCount = 0;
	private var lastFrameUpdate: Double = 0;
	
	private var paused: Bool;
	
	private let scalingFactor:CGFloat = 2.0;
	
	var dataFormat: AudioStreamBasicDescription;
	var queue: AudioQueueRef;
	var buffer: AudioQueueBufferRef;
	var buffer2: AudioQueueBufferRef;
	var bufferByteSize: UInt32;
	var numPacketsToRead: UInt32;
	var packetsToPlay: Int64;
	
	override init() {
		self.dataFormat = AudioStreamBasicDescription(mSampleRate: 0, mFormatID: 0, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: 0, mBytesPerFrame: 0, mChannelsPerFrame: 0, mBitsPerChannel: 0, mReserved: 0);
		self.queue = nil;
		self.buffer = nil;
		self.buffer2 = nil;
		self.bufferByteSize = 0x700;
		self.numPacketsToRead = 0;
		self.packetsToPlay = 1;
		
		self.paused = true;
		
		self.logger = Logger(path: "/Users/adam/nes.log");
		
		self.controllerIO = ControllerIO();
		
		dataFormat.mSampleRate = 44100;
		dataFormat.mFormatID = kAudioFormatLinearPCM;
		
		// Sort out endianness
		if (NSHostByteOrder() == NS_BigEndian) {
			dataFormat.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
		} else {
			dataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
		}
		
		dataFormat.mFramesPerPacket = 1;
		dataFormat.mBytesPerFrame = 2;
		dataFormat.mBytesPerPacket = dataFormat.mBytesPerFrame * dataFormat.mFramesPerPacket;
		dataFormat.mChannelsPerFrame = 1;
		dataFormat.mBitsPerChannel = 16;
	}
	
	func windowSetup() {
		var rect = self.window.frameRectForContentRect(NSMakeRect(0, 0, 256 * self.scalingFactor, 240 * self.scalingFactor));
		
		rect.origin = self.window.frame.origin;
		
		self.window.setFrame(rect, display: false);
		
		let windowSize = NSMakeSize(256 * self.scalingFactor, 240 * self.scalingFactor);
		
		self.window.contentMinSize = windowSize;
		self.window.contentMaxSize = windowSize;
	}

    func applicationDidFinishLaunching(aNotification: NSNotification) {
		windowSetup();
		
		self.sizingRect = self.window.convertRectToBacking(NSMakeRect(0, 0, 256 * self.scalingFactor, 240 * self.scalingFactor));
		
		let width = Int(self.sizingRect!.width);
		let height = Int(self.sizingRect!.height);
		
		self.textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: width, height: height, mipmapped: false);
		
		self.window.controllerIO = self.controllerIO;
		
		// Set up Metal
		self.device = MTLCreateSystemDefaultDevice();
		
		self.metalView.device = self.device;
		self.metalView.preferredFramesPerSecond = 60;
		self.metalView.delegate = self;
		
		self.metalView.drawableSize = CGSizeMake(self.metalView.frame.size.width, self.metalView.frame.size.height);
		
		self.commandQueue = self.device!.newCommandQueue();
		
		self.texture = self.device!.newTextureWithDescriptor(self.textureDescriptor!);
		
		self.textureLoader = MTKTextureLoader(device: self.device!);
		
		self.threadGroups = MTLSizeMake((width+threadGroupCount.width)/threadGroupCount.width, (height+threadGroupCount.height)/threadGroupCount.height, 1);
		
		let library:MTLLibrary!  = self.device.newDefaultLibrary();
		let function:MTLFunction! = library.newFunctionWithName("kernel_passthrough");
		self.pipeline = try! self.device!.newComputePipelineStateWithFunction(function);
		
		self.metalView.draw();
    }
	
	@IBAction func openROM(sender: AnyObject) {
		let openDialog = NSOpenPanel();
		
		if(openDialog.runModal() == NSFileHandlingPanelOKButton) {
			loadROM(openDialog.URL!.path!);
		}
	}
	
	@IBAction func dumpPPUMemory(sender: AnyObject) {
//		self.ppu.dumpMemory();
	}
	
	func loadROM(path: String) {
		let mapper = Mapper();
		
		let mainMemory = CPUMemory(mapper: mapper);
		mainMemory.controllerIO = controllerIO;
		
		let ppuMemory = PPUMemory(mapper: mapper);
		let fileIO = FileIO(mainMemory: mainMemory, ppuMemory: ppuMemory);
		fileIO.loadFile(path);
		
		self.apu = APU(memory: mainMemory);
		
		self.ppu = PPU(cpuMemory: mainMemory, ppuMemory: ppuMemory);
		
		mainMemory.ppu = self.ppu;
		mainMemory.apu = self.apu;
		
		self.cpu = CPU(mainMemory: mainMemory, ppu: self.ppu!, apu: self.apu!, logger: self.logger!);
		self.apu!.cpu = self.cpu!;
		self.ppu!.cpu = self.cpu!;
		
		self.cpu!.reset();
		
		initializeAudio();
		
		AudioQueueStart(queue, nil);
		
		self.paused = false;
	}
	
	// MARK: - Audio
	
	func initializeAudio() {
		AudioQueueFreeBuffer(self.queue, self.buffer);
		AudioQueueFreeBuffer(self.queue, self.buffer2);
		
		AudioQueueDispose(self.queue, true);
		
		AudioQueueNewOutput(&self.dataFormat, outputCallback, UnsafeMutablePointer<Void>(bridge(self.apu!)), CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &self.queue);
		
		AudioQueueAllocateBuffer(self.queue, self.bufferByteSize, &self.buffer);
		AudioQueueAllocateBuffer(self.queue, self.bufferByteSize, &self.buffer2);
		
		outputCallback(UnsafeMutablePointer<Void>(bridge(self.apu!)), inAudioQueue: self.queue, inBuffer: self.buffer);
		outputCallback(UnsafeMutablePointer<Void>(bridge(self.apu!)), inAudioQueue: self.queue, inBuffer: self.buffer2);
	}
	
	// MARK: - Graphics
	
	func render(inout screen: [UInt32]) {
		let width = Int(256 * self.scalingFactor);
		let height = Int(240 * self.scalingFactor);
		
		let bitsPerComponent = 8;
		
		let bytesPerPixel = 4;
		let bytesPerRow = width * bytesPerPixel;
		let colorSpace = CGColorSpaceCreateDeviceRGB();
		
		let pixels = UnsafeMutableBufferPointer<UInt32>(start: UnsafeMutablePointer<UInt32>(screen), count: screen.count);
		
		var bitmapInfo: UInt32 = CGBitmapInfo.ByteOrder32Little.rawValue;
		bitmapInfo |= CGImageAlphaInfo.NoneSkipFirst.rawValue;
		
		let imageContext = CGBitmapContextCreateWithData(pixels.baseAddress, width, height, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo, nil, nil);
		
		let image = CGBitmapContextCreateImage(imageContext);
		
		self.texture = try! self.textureLoader?.newTextureWithCGImage(image!, options: nil);
		
		let commandBuffer = commandQueue.commandBuffer()
		
		let encoder = commandBuffer.computeCommandEncoder()
		
		encoder.setComputePipelineState(pipeline)
		
		encoder.setTexture(self.texture, atIndex: 0)
		
		encoder.setTexture(metalView.currentDrawable!.texture, atIndex: 1)
		
		encoder.dispatchThreadgroups(threadGroups!, threadsPerThreadgroup: threadGroupCount)
		
		encoder.endEncoding()
		
		commandBuffer.presentDrawable(metalView.currentDrawable!)
		
		commandBuffer.commit()
	}
	
	func applicationWillTerminate(aNotification: NSNotification) {
		if(self.ppu != nil) {
			self.ppu!.dumpMemory();
			self.logger!.endLogging();
		}
    }

	// MARK: - MTKViewDelegate
	
	func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
		
	}

	func drawInMTKView(view: MTKView) {
		self.frameCount += 1;
		let now  = getTimestamp();
		let diff = now - self.lastFrameUpdate;
		if diff >= 1000 {
			let fps = (Double(self.frameCount) / diff) * 1000;
			
			self.window.title = String(format: "SwiftNES [%.0f]", fps);
			
			self.frameCount = 0;
			self.lastFrameUpdate = now;
		}
		
		if(!self.paused) {
			while(self.cpu!.step()) {
				if(self.ppu!.frameReady) {
					self.ppu!.frameReady = false;
					
					self.render(&self.ppu!.frame);
					return;
				}
			}
		}
	}
	
	func getTimestamp() -> Double {
		var tv:timeval = timeval()
		gettimeofday(&tv, nil)
		return (Double(tv.tv_sec)*1e3 + Double(tv.tv_usec)*1e-3)
	}
}

