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
	var SP: UInt8;

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
    
    // MARK: PC Operations
    func setPC(address: UInt16) {
        self.PCL = UInt8(address & 0xFF);
        self.PCH = UInt8((address & 0xFF00) >> 8);
    }
    
    func getPC() -> UInt16 {
        return UInt16(self.PCL & 0xFF) | ((UInt16(self.PCH) & UInt16(0xFF00)) >> 8);
    }
    
    func incrementPC() {
        setPC(getPC() + 1);
    }
    
    func decrementPC() {
        setPC(getPC() - 1);
    }
    
    func fetchPC() -> UInt8 {
        let byte = self.mainMemory.readMemory(Int(getPC()));
        
        incrementPC();
        
        return byte;
    }
    
    // MARK: Stack Operations
    func push(byte: UInt8) {
        self.mainMemory.writeMemory(0x100 + Int(self.SP), data: byte);
        
        if(self.SP == 0xFF) {
            print("ERROR: Stack overflow");
        }
        
        self.SP = self.SP + 1;
    }
    
    func pop() -> UInt8 {
        if(self.SP == 0) {
            print("ERROR: Stack underflow");
        }
        
        self.SP = self.SP - 1;
        
        return self.mainMemory.readMemory(0x100 + Int(self.SP));
    }
    
    // MARK: Instructions
    // MARK: Stack
    
    /**
     Simulate Interrupt ReQuest (IRQ)
    */
    func BRK() -> Int {
        // TODO: Set B flag
        push(self.PCH);
        push(self.PCL);
        push(self.P);
        
        self.PCL = self.mainMemory.readMemory(0xFFFE);
        self.PCH = self.mainMemory.readMemory(0xFFFF);
        
        return 7;
    }
    
    /**
     ReTurn from Interrupt
    */
    func RTI() -> Int {
        self.P = pop();
        self.PCL = pop();
        self.PCH = pop();
        
        return 6;
    }
    
    /**
     ReTurn from Subroutine
    */
    func RTS() -> Int {
        self.PCL = pop();
        self.PCH = pop();
        
        incrementPC();
        
        return 6;
    }
    
    /**
     PusH A
    */
    func PHA() -> Int {
        push(self.A);
        
        return 3;
    }
    
    /**
     PusH P
    */
    func PHP() -> Int {
        push(self.P);
        
        return 3;
    }
    
    /**
     PulL from Stack to A
    */
    func PLA() -> Int {
        self.A = pop();
        
        return 4;
    }
    
    /**
     PulL from Stack to P
    */
    func PLP() -> Int {
        self.P = pop();
        
        return 4;
    }
    
    /**
     Jump to SubRoutine
    */
    func JSR() -> Int {
        let lowByte = fetchPC();
        
        // TODO: Possibly incorrect?
        push(self.PCH);
        push(self.PCL);
        
        self.PCL = lowByte;
        self.PCH = fetchPC();
        
        return 6;
    }
}