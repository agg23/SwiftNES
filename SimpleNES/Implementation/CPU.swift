//
//  CPU.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

class CPU: NSObject {

	// MARK: Registers

	/**
	 Lower Half of PC
	*/
	var PCL: UInt8;

	/**
	 Upper Half of PC
	*/
	var PCH: UInt8;

	/**
	 Stack Pointer
	*/
	var SP: UInt16;

	/**
	 Processor Status
	*/
	var P: UInt8;

	/**
	 Accumulator
	*/
	var A: UInt8;

	/**
	 Index Register X
	*/
	var X: UInt8;

	/**
	 Index Register Y
	*/
	var Y: UInt8;

	var mainMemory: Memory;
    var ppuMemory: Memory;

	/**
	 Initializes the CPU
	*/
    init(mainMemory: Memory, ppuMemory: Memory) {
		self.PCL = 0;
		self.PCH = 0;

		self.SP = 0;

		self.P = 0;

		self.A = 0;
		self.X = 0;
		self.Y = 0;
		
		self.mainMemory = mainMemory;
        self.ppuMemory = ppuMemory;
    }
    
    func setPC(address: UInt16) {
        self.PCL = UInt8(address & 0xFF);
        self.PCH = UInt8((address & 0xFF00) >> 8);
    }
    
    func reset() {
        // Load program start address from RESET vector (0xFFFC)
        let programStartAddress = self.mainMemory.readTwoBytesMemory(0xFFFC);
        
        // Set PC to program start address
        setPC(programStartAddress);
        
        print("PC initialized to \((UInt16(self.PCH) << 8) | UInt16(self.PCL))");
    }

	/**
	 Executes one CPU cycle
	*/
	func step() {
		
	}
}