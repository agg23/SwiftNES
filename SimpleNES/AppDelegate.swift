//
//  AppDelegate.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Cocoa
import MetalKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, MTKViewDelegate {

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
	
	let controllerIO: ControllerIO;
	var cpu: CPU;
	var ppu: PPU;
	let logger: Logger;
	
	override init() {
		self.logger = Logger(path: "/Users/adam/nes.log");
		
		self.controllerIO = ControllerIO();
		
		let mainMemory = Memory();
		mainMemory.controllerIO = controllerIO;
		
		let ppuMemory = Memory(memoryType: Memory.MemoryType.PPU);
		let fileIO = FileIO(mainMemory: mainMemory, ppuMemory: ppuMemory);
		fileIO.loadFile("/Users/adam/Downloads/dk.nes");
		
		self.ppu = PPU(cpuMemory: mainMemory, ppuMemory: ppuMemory);
		
		mainMemory.ppu = self.ppu;
		
		self.cpu = CPU(mainMemory: mainMemory, ppu: self.ppu, logger: logger);
		self.ppu.cpu = self.cpu;
		
		self.cpu.reset();
	}

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
		
		self.sizingRect = self.window.convertRectToBacking(NSMakeRect(0, 0, 256, 240));
		
		let width = Int(self.sizingRect!.width);
		let height = Int(self.sizingRect!.height);
		
		self.textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: width, height: height, mipmapped: false);
		
		self.window.controllerIO = self.controllerIO;
		
		// Set up Metal
		self.device = MTLCreateSystemDefaultDevice();
		
		self.metalView.device = self.device;
		self.metalView.framebufferOnly = false;
		self.metalView.preferredFramesPerSecond = 60;
		self.metalView.delegate = self;
		
		self.commandQueue = self.device!.newCommandQueue();
		
		self.texture = self.device!.newTextureWithDescriptor(self.textureDescriptor!);
		
		self.textureLoader = MTKTextureLoader(device: self.device!);
		
		self.threadGroups = MTLSizeMake((width+threadGroupCount.width)/threadGroupCount.width, (height+threadGroupCount.height)/threadGroupCount.height, 1);
		
		let library:MTLLibrary!  = self.device.newDefaultLibrary();
		let function:MTLFunction! = library.newFunctionWithName("kernel_passthrough");
		self.pipeline = try! self.device!.newComputePipelineStateWithFunction(function);
		
		self.metalView.draw();
    }
	
	@IBAction func dumpPPUMemory(sender: AnyObject) {
		let logger = Logger(path: "/Users/adam/ppu.dump");
		logger.dumpMemory(self.ppu.ppuMemory.memory);
		logger.endLogging();
	}
	
	func render(screen: [RGB]) {
		let width = 256;
		let height = 240;
		
		let finalWidth = Int(self.sizingRect!.width);
		let finalHeight = Int(self.sizingRect!.height);
		
		let bitsPerComponent = 8;
		
		let bytesPerPixel = 4;
		let bytesPerRow = width * bytesPerPixel;
		let bytesPerRowFinal = finalWidth * bytesPerPixel;
		let colorSpace = CGColorSpaceCreateDeviceRGB();
		
		let pixels = UnsafeMutableBufferPointer<RGB>(start: UnsafeMutablePointer<RGB>(screen), count: screen.count);
		
		var bitmapInfo: UInt32 = CGBitmapInfo.ByteOrder32Little.rawValue;
		bitmapInfo |= CGImageAlphaInfo.NoneSkipFirst.rawValue;
		
		let imageContext = CGBitmapContextCreateWithData(pixels.baseAddress, width, height, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo, nil, nil);
		
		let image = CGBitmapContextCreateImage(imageContext);
		
		let flippedContext = CGBitmapContextCreateWithData(nil, finalWidth, finalHeight, bitsPerComponent, bytesPerRowFinal, colorSpace, bitmapInfo, nil, nil);
		
		CGContextTranslateCTM(flippedContext, 0, CGFloat(finalHeight));
		CGContextScaleCTM(flippedContext, 1.0, -1.0);
		
		let bounds = CGRect(x: 0, y: 0, width: Int(finalWidth), height: Int(finalHeight));
		
		CGContextDrawImage(flippedContext, bounds, image);
		
		let finalImage = CGBitmapContextCreateImage(flippedContext);
		
		self.texture = try! self.textureLoader?.newTextureWithCGImage(finalImage!, options: nil);
		
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
        // Insert code here to tear down your application
		self.logger.endLogging();
    }

	// MARK: - MTKViewDelegate
	
	func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
		
	}

	func drawInMTKView(view: MTKView) {
		var cpuCycles = self.cpu.step();
		
		while(cpuCycles != -1) {
			for _ in 0 ..< cpuCycles * 3 {
				if(self.ppu.step()) {
					self.render(self.ppu.frame);
					return;
				}
			}
			
			cpuCycles = self.cpu.step();
		}
	}
}

