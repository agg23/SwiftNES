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

func bridge<T : AnyObject>(_ obj : T) -> UnsafeRawPointer {
	return UnsafeRawPointer(Unmanaged.passUnretained(obj).toOpaque());
	// return unsafeAddressOf(obj) // ***
}

func bridge<T : AnyObject>(_ ptr : UnsafeRawPointer) -> T {
	return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
	// return unsafeBitCast(ptr, T.self) // ***
}

var count = 0;

func outputCallback(_ data: UnsafeMutableRawPointer?, inAudioQueue: AudioQueueRef, inBuffer: AudioQueueBufferRef) {
	let apu: APU = bridge(UnsafeRawPointer(data)!);
	
	apu.buffer.loadBuffer(inBuffer);
	
	AudioQueueEnqueueBuffer(inAudioQueue, inBuffer, 0, nil);
}

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate, MTKViewDelegate {

    @IBOutlet weak var window: DisplayWindow!
	
	@IBOutlet weak var metalView: MTKView!
	
	@IBOutlet weak var playPauseEmulationButton: NSMenuItem!
	
	private var device: MTLDevice!;
	private var commandQueue: MTLCommandQueue! = nil
	private var pipeline: MTLComputePipelineState! = nil
	
	var sizingRect: NSRect? = nil;
	
	private var texture: MTLTexture! = nil;
	private var textureOptions = [MTKTextureLoaderOptionTextureUsage: Int(MTLTextureUsage.renderTarget.rawValue) as NSNumber];
	private var textureDescriptor: MTLTextureDescriptor? = nil;
	
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
	
	private var fileLoaded: Bool;
	private var paused: Bool;
	
	private var scalingFactor:CGFloat = 2.0;
	
	var dataFormat: AudioStreamBasicDescription;
	var queue: AudioQueueRef?;
	var buffer: AudioQueueBufferRef?;
	var buffer2: AudioQueueBufferRef?;
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
		
		self.fileLoaded = false;
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
		var rect = self.window.frameRect(forContentRect: NSMakeRect(0, 0, 256 * self.scalingFactor, 240 * self.scalingFactor));
		
		rect.origin = self.window.frame.origin;
		
		self.window.setFrame(rect, display: false);
		
		let width = 256 * self.scalingFactor;
		let height = 240 * self.scalingFactor;
		
		let windowSize = NSMakeSize(width, height);
		
		self.window.contentMinSize = windowSize;
		self.window.contentMaxSize = windowSize;
		
		self.textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(with: MTLPixelFormat.bgra8Unorm, width: Int(width), height: Int(height), mipmapped: false);
		self.texture = self.device!.newTexture(with: self.textureDescriptor!);
		
		self.metalView.colorPixelFormat = MTLPixelFormat.bgra8Unorm;
	}

    func applicationDidFinishLaunching(_ aNotification: Notification) {
		self.sizingRect = self.window.convertToBacking(NSMakeRect(0, 0, 256 * self.scalingFactor, 240 * self.scalingFactor));
		
		let width = Int(self.sizingRect!.width);
		let height = Int(self.sizingRect!.height);
		
		self.window.controllerIO = self.controllerIO;
		
		// Set up Metal
		self.device = MTLCreateSystemDefaultDevice();
		
		self.metalView.device = self.device;
		self.metalView.preferredFramesPerSecond = 60;
		self.metalView.delegate = self;
		
		self.metalView.drawableSize = CGSize(width: self.metalView.frame.size.width, height: self.metalView.frame.size.height);
		
		self.commandQueue = self.device!.newCommandQueue();
		
		self.textureLoader = MTKTextureLoader(device: self.device!);
		
		self.threadGroups = MTLSizeMake((width+threadGroupCount.width)/threadGroupCount.width, (height+threadGroupCount.height)/threadGroupCount.height, 1);
		
		let library:MTLLibrary!  = self.device.newDefaultLibrary();
		let function:MTLFunction! = library.newFunction(withName: "kernel_passthrough");
		self.pipeline = try! self.device!.newComputePipelineState(with: function);
		
		windowSetup();
		
		self.metalView.draw();
    }
	
	func application(_ sender: NSApplication, openFile filename: String) -> Bool {
		return loadROM(URL(fileURLWithPath: filename));
	}
	
	// MARK: - Menu Controls
	
	@IBAction func openROM(_ sender: AnyObject) {
		let openDialog = NSOpenPanel();
		
		self.paused = true;
		
		if(openDialog.runModal() == NSFileHandlingPanelOKButton) {
			let _ = loadROM(openDialog.url!);
		}
		
		self.paused = !self.fileLoaded;
	}
	
	
	@IBAction func playPauseEmulation(_ sender: AnyObject) {
		if(!self.fileLoaded) {
			return;
		}
		
		self.paused = !self.paused;
		
		// TODO: Handle AudioQueue when paused
		if(self.paused) {
			self.playPauseEmulationButton.title = "Resume Emulation";
		} else {
			self.playPauseEmulationButton.title = "Pause Emulation";
		}
	}
	
	@IBAction func setRenderScale(_ sender: AnyObject) {
		var tag = sender.tag;
		
		if(tag == nil || tag! < 1 || tag! > 3) {
			tag = 1;
		}
		
		self.scalingFactor = CGFloat(tag!);
		if(self.ppu != nil) {
			self.ppu!.setRenderScale(tag!);
		}
		
		windowSetup();
	}
	
	@IBAction func dumpPPUMemory(_ sender: AnyObject) {
		self.ppu!.dumpMemory();
	}
	
	
	override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		if(menuItem == self.playPauseEmulationButton) {
			return self.fileLoaded;
		}
		
		return true;
	}
	
	func loadROM(_ url: URL) -> Bool {
		let mapper = Mapper();
		
		let mainMemory = CPUMemory(mapper: mapper);
		mainMemory.controllerIO = controllerIO;
		
		let ppuMemory = PPUMemory(mapper: mapper);
		let fileIO = FileIO(mainMemory: mainMemory, ppuMemory: ppuMemory);
		self.fileLoaded = fileIO.loadFile(url.path);
		
		if(!self.fileLoaded) {
			return false;
		}
		
		NSDocumentController.shared().noteNewRecentDocumentURL(url);
		
		self.playPauseEmulationButton.isEnabled = true;
		
		self.apu = APU(memory: mainMemory);
		
		self.ppu = PPU(cpuMemory: mainMemory, ppuMemory: ppuMemory);
		self.ppu!.setRenderScale(Int(self.scalingFactor));
		
		mainMemory.ppu = self.ppu;
		mainMemory.apu = self.apu;
		
		self.cpu = CPU(mainMemory: mainMemory, ppu: self.ppu!, apu: self.apu!, logger: self.logger!);
		self.apu!.cpu = self.cpu!;
		self.ppu!.cpu = self.cpu!;
		
		self.cpu!.reset();
		
		initializeAudio();
		
		AudioQueueStart(queue!, nil);
		
		self.paused = false;
		
		return true;
	}
	
	// MARK: - Audio
	
	func initializeAudio() {
		if(self.queue != nil) {
			if(self.buffer != nil) {
				AudioQueueFreeBuffer(self.queue!, self.buffer!);
			}
			
			if(self.buffer2 != nil) {
				AudioQueueFreeBuffer(self.queue!, self.buffer2!);
			}
			
			AudioQueueDispose(self.queue!, true);
		}
		
		AudioQueueNewOutput(&self.dataFormat, outputCallback, UnsafeMutableRawPointer(mutating: bridge(self.apu!)), CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue, 0, &self.queue);
		
		AudioQueueAllocateBuffer(self.queue!, self.bufferByteSize, &self.buffer);
		AudioQueueAllocateBuffer(self.queue!, self.bufferByteSize, &self.buffer2);
		
		outputCallback(UnsafeMutableRawPointer(mutating: bridge(self.apu!)), inAudioQueue: self.queue!, inBuffer: self.buffer!);
		outputCallback(UnsafeMutableRawPointer(mutating: bridge(self.apu!)), inAudioQueue: self.queue!, inBuffer: self.buffer2!);
	}
	
	// MARK: - Graphics
	
	func render(_ screen: inout [UInt32]) {
		let width = Int(256 * self.scalingFactor);
		let height = Int(240 * self.scalingFactor);
		
		let bytesPerPixel = 4;
		let bytesPerRow = width * bytesPerPixel;
		
		self.metalView.currentDrawable!.texture.replace(MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: UnsafeRawPointer(screen), bytesPerRow: bytesPerRow);
		
		let commandBuffer = commandQueue.commandBuffer()
		
		commandBuffer.present(metalView.currentDrawable!)
		
		commandBuffer.commit()
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
		if(self.ppu != nil) {
			self.logger!.endLogging();
		}
    }

	// MARK: - MTKViewDelegate
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		
	}

	func draw(in view: MTKView) {
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

