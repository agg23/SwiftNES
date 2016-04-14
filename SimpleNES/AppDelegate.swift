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
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

	@IBOutlet weak var imageView: NSImageView!
	
	@IBOutlet weak var metalView: MTKView!
	
	private var device: MTLDevice!;
	private var commandQueue: MTLCommandQueue! = nil
	private var pipeline: MTLComputePipelineState! = nil
	
	private let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: 256, height: 240, mipmapped: false);
	
	private var texture: MTLTexture! = nil;
	
	private let threadGroupCount = MTLSizeMake(8, 8, 1);
	private var threadGroups: MTLSize?;
	
	private var textureLoader: MTKTextureLoader?;
	
	var ppu: PPU?;

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
		
		// Set up Metal
		self.device = MTLCreateSystemDefaultDevice();
		
		self.metalView.device = self.device;
		
		self.metalView.framebufferOnly = false;
		
		self.commandQueue = self.device!.newCommandQueue();
		
		self.texture = self.device!.newTextureWithDescriptor(self.textureDescriptor);
		
		self.textureLoader = MTKTextureLoader(device: self.device!);
		
		self.threadGroups = MTLSizeMake((256+threadGroupCount.width)/threadGroupCount.width, (240+threadGroupCount.height)/threadGroupCount.height, 1);
		
		let library:MTLLibrary!  = self.device.newDefaultLibrary();
		let function:MTLFunction! = library.newFunctionWithName("kernel_passthrough");
		self.pipeline = try! self.device!.newComputePipelineStateWithFunction(function);
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
			self.run();
		})
    }
	
	func run() {
		let logger = Logger(path: "/Users/adam/nes.log");
		let mainMemory = Memory();
		let ppuMemory = Memory(memoryType: Memory.MemoryType.PPU);
		let fileIO = FileIO(mainMemory: mainMemory, ppuMemory: ppuMemory);
		fileIO.loadFile("/Users/adam/Downloads/dk.nes");
		
		let ppu = PPU(cpuMemory: mainMemory, ppuMemory: ppuMemory);
		
		self.ppu = ppu;
		
		mainMemory.ppu = ppu;
		let cpu = CPU(mainMemory: mainMemory, ppu: ppu, logger: logger);
		ppu.cpu = cpu;
		
		cpu.reset();
//		cpu.setPC(0xC000);
		
		var cpuCycles = cpu.step();
		
		while(cpuCycles != -1) {
			for _ in 0 ..< cpuCycles * 3 {
				if(ppu.step()) {
					dispatch_async(dispatch_get_main_queue(), {
//						let start = NSDate();
						//self.render(ppu.frame);
						self.render(ppu.frame);
//						let end = NSDate();
						
//						print("Drew frame in \(end.timeIntervalSinceDate(start))");
					})
				}
			}
			
			cpuCycles = cpu.step();
		}
		
		print("Reset Vector: \(mainMemory.readTwoBytesMemory(0xFFFC))");
		print("First Opcode: \(mainMemory.readMemory(0xf415))");
		
		logger.endLogging();

	}
	
	@IBAction func dumpPPUMemory(sender: AnyObject) {
		let logger = Logger(path: "/Users/adam/ppu.dump");
		logger.dumpMemory(self.ppu!.ppuMemory.memory);
		logger.endLogging();
	}
	
	func render(screen: [RGB]) {
		let width = 256;
		let height = 240;
		
		let bitsPerComponent = 8;
		
		let bytesPerPixel = 4;
		let bytesPerRow = width * bytesPerPixel;
		let colorSpace = CGColorSpaceCreateDeviceRGB();
		
		let pixels = UnsafeMutableBufferPointer<RGB>(start: UnsafeMutablePointer<RGB>(screen), count: screen.count);
		
		var bitmapInfo: UInt32 = CGBitmapInfo.ByteOrder32Little.rawValue;
		bitmapInfo |= CGImageAlphaInfo.NoneSkipFirst.rawValue;
		
		let imageContext = CGBitmapContextCreateWithData(pixels.baseAddress, width, height, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo, nil, nil);
		
		let image = CGBitmapContextCreateImage(imageContext);
		
		let flippedContext = CGBitmapContextCreateWithData(nil, width, height, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo, nil, nil);
		
		CGContextTranslateCTM(flippedContext, 0, CGFloat(height));
		CGContextScaleCTM(flippedContext, 1.0, -1.0);
		
		let bounds = CGRect(x: 0, y: 0, width: Int(width), height: Int(height));
		
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
    }


}

