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
		var mainMemory = Memory();
		var ppuMemory = Memory(memoryType: true);
		var fileIO = FileIO(mainMemory: mainMemory, ppuMemory: ppuMemory);
		fileIO.loadFile("/Users/adam/Downloads/nestest.nes");
        
        var cpu = CPU(mainMemory: mainMemory, ppuMemory: ppuMemory);
        cpu.reset();
		cpu.setPC(0xC000);
		
		while(cpu.step() != -1) {
			
		}
		
		print("Reset Vector: \(mainMemory.readTwoBytesMemory(0xFFFC))");
        print("First Opcode: \(mainMemory.readMemory(0xf415))");
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

