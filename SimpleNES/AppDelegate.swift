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
		let logger = Logger(path: "/Users/adam/nes.log");
		var mainMemory = Memory();
		var ppuMemory = Memory(memoryType: true);
		var fileIO = FileIO(mainMemory: mainMemory, ppuMemory: ppuMemory);
		fileIO.loadFile("/Users/adam/Downloads/nestest.nes");
		
		let ppu = PPU(cpuMemory: mainMemory, ppuMemory: ppuMemory);
		mainMemory.ppu = ppu;
        var cpu = CPU(mainMemory: mainMemory, ppu: ppu, logger: logger);
        cpu.reset();
		cpu.setPC(0xC000);
		
		while(cpu.step() != -1) {
			
		}
		
		print("Reset Vector: \(mainMemory.readTwoBytesMemory(0xFFFC))");
        print("First Opcode: \(mainMemory.readMemory(0xf415))");
		
		logger.endLogging();
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

