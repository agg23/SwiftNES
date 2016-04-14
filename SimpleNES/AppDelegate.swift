//
//  AppDelegate.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

	@IBOutlet weak var imageView: NSImageView!
	
	var ppu: PPU?;

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
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
		/*var screen = [RGB](count:Int(256*240), repeatedValue:RGB(r:0, g:0, b:0));
		
		for i in 0 ..< 240 {
			for k in 0 ..< 256 {
				screen[i * 256 + k] = RGB(r: UInt8(frame[i][k]), g: 0, b: 0);
			}
		}*/
		
//		print("Drawing frame");
		
		let context: CGContext! = self.window.graphicsContext?.CGContext;
		
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
		
//		CGContextScaleCTM(imageContext, 2.0, 2.0);
		
		CGContextConcatCTM(context, CGAffineTransformMakeScale(2, 2));
		
		let image = CGBitmapContextCreateImage(imageContext);
		
//		CGContextDrawImage(context, CGRect(x: 0, y: 0, width: 256, height: 240), image);
		
		let nsImage = NSImage(CGImage: image!, size: NSZeroSize);
		
		self.imageView.image = nsImage;
	}

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

