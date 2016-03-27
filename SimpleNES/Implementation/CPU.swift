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
    
    enum AddressingMode {
        case Implied
        
        case Immediate
        
        case Absolute
        case AbsoluteIndexedX
        case AbsoluteIndexedY
        
        /**
         For JMP only
         */
        case AbsoluteIndirect
        
        case ZeroPage
        case ZeroPageIndexedX
        case ZeroPageIndexedY
        
        case IndirectX
        case IndirectY
        
        case Relative
    }

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
    
    func address(lower:UInt8, upper:UInt8) -> Int {
        return Int(lower) | (Int(upper) << 8);
    }
    
    func setPBit(index: Int, value: Bool) {
        let bit: UInt8 = value ? 0xFF : 0;
        self.P ^= (bit ^ self.P) & (1 << UInt8(index));
    }
    
    func getPBit(index: Int) -> Bool {
        return ((self.P >> UInt8(index)) & 0x1) == 1;
    }
    
    // MARK: PC Operations
    func setPC(address: UInt16) {
        self.PCL = UInt8(address & 0xFF);
        self.PCH = UInt8((address & 0xFF00) >> 8);
    }
    
    func getPC() -> UInt16 {
        return UInt16(self.PCL) | (UInt16(self.PCH) << 8);
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
    
    // MARK: Absolute Addressing
    
    /**
     JuMP
    */
    func JMP(mode: AddressingMode) -> Int {
        switch mode {
            case AddressingMode.Absolute:
                let lowByte = fetchPC();
                
                self.PCH = fetchPC();
                self.PCL = lowByte;
            case AddressingMode.AbsoluteIndirect:
                let zeroPageAddress = fetchPC();
                
                self.PCL = self.mainMemory.readMemory(Int(zeroPageAddress));
                self.PCH = self.mainMemory.readMemory(Int(zeroPageAddress) + 1);
            default:
                print("Invalid AddressingMode on JMP");
        }
        
        return 3;
    }
    
    /**
     Load A from Memory
    */
    func LDA(mode: AddressingMode) -> Int {
        switch mode {
            case .Immediate, .ZeroPage, .ZeroPageIndexedX,
                 .Absolute, .AbsoluteIndexedX, .AbsoluteIndexedY,
                 .IndirectX, .IndirectY:
                return LOAD(mode, register: &self.A);
            default:
                print("Invalid AddressingMode on LDA");
        }
        
        return -1;
    }
    
    /**
     Load X from Memory
    */
    func LDX(mode: AddressingMode) -> Int {
        switch mode {
            case .Immediate, .ZeroPage, .ZeroPageIndexedY,
                 .Absolute, .AbsoluteIndexedY:
                return LOAD(mode, register: &self.X);
            default:
                print("Invalid AddressingMode on LDX");
        }
        
        return -1;
    }
    
    /**
     Load Y from Memory
    */
    func LDY(mode: AddressingMode) -> Int {
        switch mode {
            case .Immediate, .ZeroPage, .ZeroPageIndexedX,
                 .Absolute, .AbsoluteIndexedX:
                return LOAD(mode, register: &self.Y);
            default:
                print("Invalid AddressingMode on LDY");
        }
        
        return -1;
    }
    
    /**
     Internal handler for LDA, LDX, LDY
    */
    func LOAD(mode: AddressingMode, register: UnsafeMutablePointer<UInt8>) -> Int {
        var length = 4;
        
        switch mode {
            case AddressingMode.Immediate:
                length = 2;
                register.memory = fetchPC();
            
            case AddressingMode.ZeroPage:
                length = 3;
                register.memory = self.mainMemory.readMemory(Int(fetchPC()));
            
            case AddressingMode.ZeroPageIndexedX, .ZeroPageIndexedY:
                var index = self.X;
                
                if(mode == AddressingMode.ZeroPageIndexedY) {
                    index = self.Y;
                }
                
                register.memory = self.mainMemory.readMemory(Int((fetchPC() + index) & 0xFF));
            
            case AddressingMode.Absolute:
                let lowByte = fetchPC();
                let highByte = fetchPC();
            
                register.memory = self.mainMemory.readMemory(address(lowByte, upper: highByte));
            
            case AddressingMode.AbsoluteIndexedX, .AbsoluteIndexedY:
                let lowByte = fetchPC();
                let highByte = fetchPC();
                
                var index = self.X;
                
                if(mode == AddressingMode.AbsoluteIndexedY) {
                    index = self.Y;
                }
                
                let originalAddress = address(lowByte, upper: highByte);
                
                register.memory = self.mainMemory.readMemory(Int((UInt16(originalAddress) + UInt16(index)) & 0xFFFF));
            
            case AddressingMode.IndirectX:
                length = 6;
                
                let immediate = fetchPC();
            
                let lowByte = self.mainMemory.readMemory(Int((immediate + self.X) & 0xFF));
                let highByte = self.mainMemory.readMemory(Int((immediate + self.X + 1) & 0xFF));
            
                register.memory = self.mainMemory.readMemory(address(lowByte, upper: highByte));
            
            case AddressingMode.IndirectY:
                length = 5;
            
                let immediate = fetchPC();
            
                let lowByte = self.mainMemory.readMemory(Int(immediate));
                let highByte = self.mainMemory.readMemory(Int(UInt8((immediate + 1) & 0xFF)));
                
                let originalAddress = address(lowByte, upper: highByte);
            
                register.memory = self.mainMemory.readMemory(Int((UInt16(originalAddress) + UInt16(self.Y)) & 0xFFFF));

            default:
                print("Invalid AddressingMode on LOAD");
        }
        
        // Set negative flag
        setPBit(7, value: (self.A >> 8) == 1);
        
        // Set zero flag
        setPBit(1, value: (A == 0));
        
        let lowByte = fetchPC();
        let highByte = fetchPC();
        
        self.A = self.mainMemory.readMemory(address(lowByte, upper: highByte));
        
        return length;
    }
}