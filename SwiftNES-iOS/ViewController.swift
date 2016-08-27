//
//  ViewController.swift
//  SwiftNES-iOS
//
//  Created by Adam Gastineau on 6/19/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import UIKit
import QuartzCore
import Metal
import MetalKit

class ViewController: UIViewController, MTKViewDelegate {

	@IBOutlet weak var metalView: MTKView!;
	
	private var device: MTLDevice!;
	private var commandQueue: MTLCommandQueue! = nil
	private var pipeline: MTLComputePipelineState! = nil
	
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
	
	required init?(coder aDecoder: NSCoder) {
//		self.dataFormat = AudioStreamBasicDescription(mSampleRate: 0, mFormatID: 0, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: 0, mBytesPerFrame: 0, mChannelsPerFrame: 0, mBitsPerChannel: 0, mReserved: 0);
//		self.queue = nil;
//		self.buffer = nil;
//		self.buffer2 = nil;
//		self.bufferByteSize = 0x700;
//		self.numPacketsToRead = 0;
//		self.packetsToPlay = 1;
		
		self.logger = Logger(path: "/Users/adam/nes.log");
		
		self.controllerIO = ControllerIO();
		
		self.fileLoaded = false;
		self.paused = true;
		
		super.init(coder: aDecoder);
		
//		dataFormat.mSampleRate = 44100;
//		dataFormat.mFormatID = kAudioFormatLinearPCM;
//		
//		// Sort out endianness
//		if (NSHostByteOrder() == NS_BigEndian) {
//			dataFormat.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
//		} else {
//			dataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
//		}
//		
//		dataFormat.mFramesPerPacket = 1;
//		dataFormat.mBytesPerFrame = 2;
//		dataFormat.mBytesPerPacket = dataFormat.mBytesPerFrame * dataFormat.mFramesPerPacket;
//		dataFormat.mChannelsPerFrame = 1;
//		dataFormat.mBitsPerChannel = 16;
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		self.device = MTLCreateSystemDefaultDevice();
		
		self.metalView.device = self.device;
		self.metalView.preferredFramesPerSecond = 60;
		self.metalView.delegate = self;
		self.metalView.framebufferOnly = false;
		
		self.metalView.drawableSize = CGSize(width: self.metalView.frame.size.width, height: self.metalView.frame.size.height);
		
		self.commandQueue = self.device!.newCommandQueue();
		
		self.textureLoader = MTKTextureLoader(device: self.device!);
		
//		self.threadGroups = MTLSizeMake((width+threadGroupCount.width)/threadGroupCount.width, (height+threadGroupCount.height)/threadGroupCount.height, 1);
//		
//		let library:MTLLibrary!  = self.device.newDefaultLibrary();
//		let function:MTLFunction! = library.newFunction(withName: "kernel_passthrough");
//		self.pipeline = try! self.device!.newComputePipelineState(with: function);
		
//		windowSetup();
		
		self.metalView.draw();
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	func loadROM(_ url: URL) -> Bool {
		let mapper = Mapper();
		
		let mainMemory = CPUMemory(mapper: mapper);
		mainMemory.controllerIO = controllerIO;
		
		let ppuMemory = PPUMemory(mapper: mapper);
		let fileIO = FileIO(mainMemory: mainMemory, ppuMemory: ppuMemory);
		fileIO.loadFile(url.path);
		
//		NSDocumentController.shared().noteNewRecentDocumentURL(url);
		
//		self.playPauseEmulationButton.isEnabled = true;
		
		self.apu = APU(memory: mainMemory);
		
		self.ppu = PPU(cpuMemory: mainMemory, ppuMemory: ppuMemory);
		self.ppu!.setRenderScale(1);
		
		mainMemory.ppu = self.ppu;
		mainMemory.apu = self.apu;
		
		self.cpu = CPU(mainMemory: mainMemory, ppu: self.ppu!, apu: self.apu!, logger: self.logger!);
		self.apu!.cpu = self.cpu!;
		self.ppu!.cpu = self.cpu!;
		
		self.cpu!.reset();
		
//		initializeAudio();
//		
//		AudioQueueStart(queue!, nil);
//		
		self.paused = false;
		
		return true;
	}
	
	func render(_ screen: inout [UInt32]) {
		let width = Int(256 * 1);
		let height = Int(240 * 1);
		
		let bytesPerPixel = 4;
		let bytesPerRow = width * bytesPerPixel;
		
//		let drawable = self.metalView.currentDrawable!.texture
		self.metalView.currentDrawable!.texture.replace(MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: UnsafeRawPointer(screen), bytesPerRow: bytesPerRow);
		
		let commandBuffer = commandQueue.commandBuffer()
		
		commandBuffer.present(metalView.currentDrawable!)
		
		commandBuffer.commit()
	}

	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		
	}
	
	func draw(in view: MTKView) {
		self.frameCount += 1;
		let now  = getTimestamp();
		let diff = now - self.lastFrameUpdate;
		if diff >= 1000 {
			let fps = (Double(self.frameCount) / diff) * 1000;
			
//			self.window.title = String(format: "SwiftNES [%.0f]", fps);
			
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
	
	@IBAction func run(_ sender: AnyObject) {
		print(loadROM(Bundle.main.url(forResource: "smb3", withExtension: "nes")!));
	}
}

