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
		fileIO.loadFile("/Users/adam/Downloads/nestest.nes");
		
		let ppu = PPU(cpuMemory: mainMemory, ppuMemory: ppuMemory);
		mainMemory.ppu = ppu;
		let cpu = CPU(mainMemory: mainMemory, ppu: ppu, logger: logger);
		ppu.cpu = cpu;
		
		cpu.reset();
		cpu.setPC(0xC000);
		
		var cpuCycles = cpu.step();
		
		while(cpuCycles != -1) {
			for _ in 0 ..< cpuCycles * 3 {
				if(ppu.renderScanline()) {
					/*dispatch_async(dispatch_get_main_queue(), {
						self.render(ppu.frame);
					})*/
				}
			}
			
			cpuCycles = cpu.step();
		}
		
		print("Reset Vector: \(mainMemory.readTwoBytesMemory(0xFFFC))");
		print("First Opcode: \(mainMemory.readMemory(0xf415))");
		
		logger.endLogging();

	}
	
	func render(screen: [RGB]) {
		/*var screen = [RGB](count:Int(256*240), repeatedValue:RGB(r:0, g:0, b:0));
		
		for i in 0 ..< 240 {
			for k in 0 ..< 256 {
				screen[i * 256 + k] = RGB(r: UInt8(frame[i][k]), g: 0, b: 0);
			}
		}*/
		
		print("Drawing frame");
		
		let context: CGContext! = self.window.graphicsContext?.CGContext;
		let data = NSData(bytes: screen, length: screen.count * sizeof(RGB))
		let provider = CGDataProviderCreateWithCFData(data)
		let colorspace = CGColorSpaceCreateDeviceRGB()
		let info = CGBitmapInfo.ByteOrderDefault
		
		let image = CGImageCreate(256, 240, 8, 24, 3 * 256, colorspace, info, provider, nil, false, CGColorRenderingIntent.RenderingIntentDefault);
		
		CGContextSetInterpolationQuality(context, CGInterpolationQuality.None);
		CGContextSetShouldAntialias(context, false);
		CGContextScaleCTM(context, 2, 2);
		
		CGContextDrawImage(context, CGRect(x: 0, y: 0, width: 256, height: 240), image);
	}

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

