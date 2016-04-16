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
	
	
	/**
	 The queued interrupt
	*/
	var interrupt: Interrupt?;

	let mainMemory: Memory;
    let ppu: PPU;
	
	let logger: Logger;
	
	/**
	 True if the last cycle run by the CPU was even
	*/
	var evenCycle = true;
	
	/**
	 True if page was crossed by last instruction
	*/
	var pageCrossed = false;
	
	/**
	 True if CPU is current running an OAM transfer
	*/
	var oamTransfer = false;
	
	/**
	 Stores the number of cycles in the current OAM transfer
	*/
	var oamCycles = 0;
	
	/**
	 Stores whether OAM transfer will have an extra cycle
	*/
	var oamExtraCycle = false;
	
	/**
	 True if an error occurred
	*/
	var errorOccured = false;
	
	let loggingQueue = dispatch_queue_create("com.appcannon.simplenes.loggingqueue", DISPATCH_QUEUE_SERIAL);
	
    enum AddressingMode {
        case Accumulator
        
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
	
	enum Interrupt {
		case VBlank
		
		case RESET
		
		case Software
	}

	/**
	 Initializes the CPU
	*/
	init(mainMemory: Memory, ppu: PPU, logger: Logger) {
		self.PCL = 0;
		self.PCH = 0;

		self.SP = 0;

		self.P = 0;

		self.A = 0;
		self.X = 0;
		self.Y = 0;
		
		self.mainMemory = mainMemory;
        self.ppu = ppu;
		self.logger = logger;
    }
    
    func reset() {
        // Load program start address from RESET vector (0xFFFC)
        let programStartAddress = self.mainMemory.readTwoBytesMemory(0xFFFC);
		
		self.interrupt = nil;
		
		self.SP = 0xFD;
		
		// Set interrupt flag
		setPBit(2, value: true);
		
		// Set unused flag
		setPBit(5, value: true);
        
        // Set PC to program start address
        setPC(programStartAddress);
        
        print("PC initialized to \((UInt16(self.PCH) << 8) | UInt16(self.PCL))");
    }
	
	/**
	Executes one CPU instruction
	
	- Returns: Number of cycles required by the run instruction
	*/
	func step() -> Int {
		var cycleCount = stepNoPageCheck();
		
		if(self.pageCrossed) {
			cycleCount += 1;
		}
		
		self.evenCycle = self.evenCycle && (cycleCount % 2 == 0);
		
		return cycleCount;
	}

	/**
	 Executes one CPU instruction
	
	 - Returns: Number of cycles required by the run instruction, excepting perhaps cycles due
			to page crosses
	*/
	func stepNoPageCheck() -> Int {
		self.pageCrossed = false;
		
		if(self.oamTransfer) {
			self.oamCycles += 1;
			
			// End the transfer
			if((self.oamCycles > 513 && !self.oamExtraCycle) || (self.oamCycles > 514 && self.oamExtraCycle)) {
				self.oamCycles = 0;
				self.oamTransfer = false;
			}
			
			return 1;
		}
		
		if(self.interrupt != nil) {
			if(self.interrupt == Interrupt.Software) {
				if(!getPBit(2)) {
					handleInterrupt();
					
					return 7;
				}
			} else {
				handleInterrupt();
				
				return 7;
			}
		}
		
		self.interrupt = nil;
		
		let opcode = fetchPC();
		
//		print(String(format: "PC: 0x%2x. Executing 0x%2x", getPC() - 1, opcode));
//		dispatch_async(loggingQueue, {
//			self.logger.logFormattedInstuction(self.getPC() - 1, opcode: opcode, A: self.A, X: self.X, Y: self.Y, P: self.P, SP: self.SP, CYC: self.ppu.cycle, SL: self.ppu.scanline);
//		})
		
		switch opcode {
			// ADC
			case 0x69:
				return ADC(.Immediate);
			case 0x65:
				return ADC(.ZeroPage);
			case 0x75:
				return ADC(.ZeroPageIndexedX);
			case 0x6D:
				return ADC(.Absolute);
			case 0x7D:
				return ADC(.AbsoluteIndexedX);
			case 0x79:
				return ADC(.AbsoluteIndexedY);
			case 0x61:
				return ADC(.IndirectX);
			case 0x71:
				return ADC(.IndirectY);
			
			// ALR
			case 0x4B:
				return ALR();
			
			// ANC
			case 0x0B, 0x2B:
				return ANC();
			
			// AND
			case 0x29:
				return AND(.Immediate);
			case 0x25:
				return AND(.ZeroPage);
			case 0x35:
				return AND(.ZeroPageIndexedX);
			case 0x2D:
				return AND(.Absolute);
			case 0x3D:
				return AND(.AbsoluteIndexedX);
			case 0x39:
				return AND(.AbsoluteIndexedY);
			case 0x21:
				return AND(.IndirectX);
			case 0x31:
				return AND(.IndirectY);
				
			// ASL
			case 0x0A:
				return ASL(.Accumulator);
			case 0x06:
				return ASL(.ZeroPage);
			case 0x16:
				return ASL(.ZeroPageIndexedX);
			case 0x0E:
				return ASL(.Absolute);
			case 0x1E:
				return ASL(.AbsoluteIndexedX);
			
			// ARR
			case 0x6B:
				return ARR();
			
			// AXS
			case 0xCB:
				return AXS();
			
			// BCC
			case 0x90:
				return BCC();
				
			// BCS
			case 0xB0:
				return BCS();
				
			// BEQ
			case 0xF0:
				return BEQ();
				
			// BIT
			case 0x24:
				return BIT(.ZeroPage);
			case 0x2C:
				return BIT(.Absolute);
				
			// BMI
			case 0x30:
				return BMI();
				
			// BNE
			case 0xD0:
				return BNE();
				
			// BPL
			case 0x10:
				return BPL();
				
			// BRK
			case 0x00:
				return BRK();
				
			// BVC
			case 0x50:
				return BVC();
				
			// BVS
			case 0x70:
				return BVS();
				
			// CLC
			case 0x18:
				return CLC();
				
			// CLD
			case 0xD8:
				return CLD();
				
			// CLI
			case 0x58:
				return CLI();
				
			// CLV
			case 0xB8:
				return CLV();
				
			// CMP
			case 0xC9:
				return CMP(.Immediate);
			case 0xC5:
				return CMP(.ZeroPage);
			case 0xD5:
				return CMP(.ZeroPageIndexedX);
			case 0xCD:
				return CMP(.Absolute);
			case 0xDD:
				return CMP(.AbsoluteIndexedX);
			case 0xD9:
				return CMP(.AbsoluteIndexedY);
			case 0xC1:
				return CMP(.IndirectX);
			case 0xD1:
				return CMP(.IndirectY);
				
			// CPX
			case 0xE0:
				return CPX(.Immediate);
			case 0xE4:
				return CPX(.ZeroPage);
			case 0xEC:
				return CPX(.Absolute);
				
			// CPY
			case 0xC0:
				return CPY(.Immediate);
			case 0xC4:
				return CPY(.ZeroPage);
			case 0xCC:
				return CPY(.Absolute);
			
			// DCP
			case 0xCF:
				return DCP(.Absolute);
			case 0xDB:
				return DCP(.AbsoluteIndexedY);
			case 0xDF:
				return DCP(.AbsoluteIndexedX);
			case 0xC7:
				return DCP(.ZeroPage);
			case 0xD7:
				return DCP(.ZeroPageIndexedX);
			case 0xC3:
				return DCP(.IndirectX);
			case 0xD3:
				return DCP(.IndirectY);
			
			// DEC
			case 0xC6:
				return DEC(.ZeroPage);
			case 0xD6:
				return DEC(.ZeroPageIndexedX);
			case 0xCE:
				return DEC(.Absolute);
			case 0xDE:
				return DEC(.AbsoluteIndexedX);
				
			// DEX
			case 0xCA:
				return DEX();
				
			// DEY
			case 0x88:
				return DEY();
				
			// EOR
			case 0x49:
				return EOR(.Immediate);
			case 0x45:
				return EOR(.ZeroPage);
			case 0x55:
				return EOR(.ZeroPageIndexedX);
			case 0x4D:
				return EOR(.Absolute);
			case 0x5D:
				return EOR(.AbsoluteIndexedX);
			case 0x59:
				return EOR(.AbsoluteIndexedY);
			case 0x41:
				return EOR(.IndirectX);
			case 0x51:
				return EOR(.IndirectY);
			
			// IGN
			case 0x0C:
				return IGN(.Absolute);
			case 0x1C, 0x3C, 0x5C, 0x7C, 0xDC, 0xFC:
				return IGN(.AbsoluteIndexedX);
			case 0x04, 0x44, 0x64:
				return IGN(.ZeroPage);
			case 0x14, 0x34, 0x54, 0x74, 0xD4, 0xF4:
				return IGN(.ZeroPageIndexedX);
			
			// INC
			case 0xE6:
				return INC(.ZeroPage);
			case 0xF6:
				return INC(.ZeroPageIndexedX);
			case 0xEE:
				return INC(.Absolute);
			case 0xFE:
				return INC(.AbsoluteIndexedX);
				
			// INX
			case 0xE8:
				return INX();
				
			// INY
			case 0xC8:
				return INY();
			
			// ISC
			case 0xEF:
				return ISC(.Absolute);
			case 0xFF:
				return ISC(.AbsoluteIndexedX);
			case 0xFB:
				return ISC(.AbsoluteIndexedY);
			case 0xE7:
				return ISC(.ZeroPage);
			case 0xF7:
				return ISC(.ZeroPageIndexedX);
			case 0xE3:
				return ISC(.IndirectX);
			case 0xF3:
				return ISC(.IndirectY);
			
			// JMP
			case 0x4C:
				return JMP(.Absolute);
			case 0x6C:
				return JMP(.AbsoluteIndirect);
				
			// JSR
			case 0x20:
				return JSR();
			
			// LAX
			case 0xA7:
				return LAX(.ZeroPage);
			case 0xB7:
				return LAX(.ZeroPageIndexedY);
			case 0xAF:
				return LAX(.Absolute);
			case 0xBF:
				return LAX(.AbsoluteIndexedY);
			case 0xA3:
				return LAX(.IndirectX);
			case 0xB3:
				return LAX(.IndirectY);
			
			// LDA
			case 0xA9:
				return LDA(.Immediate);
			case 0xA5:
				return LDA(.ZeroPage);
			case 0xB5:
				return LDA(.ZeroPageIndexedX);
			case 0xAD:
				return LDA(.Absolute);
			case 0xBD:
				return LDA(.AbsoluteIndexedX);
			case 0xB9:
				return LDA(.AbsoluteIndexedY);
			case 0xA1:
				return LDA(.IndirectX);
			case 0xB1:
				return LDA(.IndirectY);
				
			// LDX
			case 0xA2:
				return LDX(.Immediate);
			case 0xA6:
				return LDX(.ZeroPage);
			case 0xB6:
				return LDX(.ZeroPageIndexedY);
			case 0xAE:
				return LDX(.Absolute);
			case 0xBE:
				return LDX(.AbsoluteIndexedY);
				
			// LDY
			case 0xA0:
				return LDY(.Immediate);
			case 0xA4:
				return LDY(.ZeroPage);
			case 0xB4:
				return LDY(.ZeroPageIndexedX);
			case 0xAC:
				return LDY(.Absolute);
			case 0xBC:
				return LDY(.AbsoluteIndexedX);
			
			// LXA
			// Assuming XAA (0x8B) is the same as LXA
			case 0x8B, 0xAB:
				return LXA();
			
			// LSR
			case 0x4A:
				return LSR(.Accumulator);
			case 0x46:
				return LSR(.ZeroPage);
			case 0x56:
				return LSR(.ZeroPageIndexedX);
			case 0x4E:
				return LSR(.Absolute);
			case 0x5E:
				return LSR(.AbsoluteIndexedX);
				
			// NOP
			case 0xEA, 0x1A, 0x3A, 0x5A, 0x7A, 0xDA, 0xEA, 0xFA:
				return NOP();
				
			// ORA
			case 0x09:
				return ORA(.Immediate);
			case 0x05:
				return ORA(.ZeroPage);
			case 0x15:
				return ORA(.ZeroPageIndexedX);
			case 0x0D:
				return ORA(.Absolute);
			case 0x1D:
				return ORA(.AbsoluteIndexedX);
			case 0x19:
				return ORA(.AbsoluteIndexedY);
			case 0x01:
				return ORA(.IndirectX);
			case 0x11:
				return ORA(.IndirectY);
				
			// PHA
			case 0x48:
				return PHA();
				
			// PHP
			case 0x08:
				return PHP();
				
			// PLA
			case 0x68:
				return PLA();
				
			// PLP
			case 0x28:
				return PLP();
			
			// RLA
			case 0x2F:
				return RLA(.Absolute);
			case 0x3F:
				return RLA(.AbsoluteIndexedX);
			case 0x3B:
				return RLA(.AbsoluteIndexedY);
			case 0x27:
				return RLA(.ZeroPage);
			case 0x37:
				return RLA(.ZeroPageIndexedX);
			case 0x23:
				return RLA(.IndirectX);
			case 0x33:
				return RLA(.IndirectY);
			
			// ROL
			case 0x2A:
				return ROL(.Accumulator);
			case 0x26:
				return ROL(.ZeroPage);
			case 0x36:
				return ROL(.ZeroPageIndexedX);
			case 0x2E:
				return ROL(.Absolute);
			case 0x3E:
				return ROL(.AbsoluteIndexedX);
				
			// ROR
			case 0x6A:
				return ROR(.Accumulator);
			case 0x66:
				return ROR(.ZeroPage);
			case 0x76:
				return ROR(.ZeroPageIndexedX);
			case 0x6E:
				return ROR(.Absolute);
			case 0x7E:
				return ROR(.AbsoluteIndexedX);
            
            // RRA
            case 0x6F:
                return RRA(.Absolute);
            case 0x7F:
                return RRA(.AbsoluteIndexedX);
            case 0x7B:
                return RRA(.AbsoluteIndexedY);
            case 0x67:
                return RRA(.ZeroPage);
            case 0x77:
                return RRA(.ZeroPageIndexedX);
            case 0x63:
                return RRA(.IndirectX);
            case 0x73:
                return RRA(.IndirectY);
				
			// RTI
			case 0x40:
				return RTI();
				
			// RTS
			case 0x60:
				return RTS();
			
			// SAX
			case 0x8F:
				return SAX(.Absolute);
			case 0x87:
				return SAX(.ZeroPage);
			case 0x83:
				return SAX(.IndirectX);
			case 0x97:
				return SAX(.ZeroPageIndexedY);
			
			// SBC
			case 0xE9, 0xEB:
				return SBC(.Immediate);
			case 0xE5:
				return SBC(.ZeroPage);
			case 0xF5:
				return SBC(.ZeroPageIndexedX);
			case 0xED:
				return SBC(.Absolute);
			case 0xFD:
				return SBC(.AbsoluteIndexedX);
			case 0xF9:
				return SBC(.AbsoluteIndexedY);
			case 0xE1:
				return SBC(.IndirectX);
			case 0xF1:
				return SBC(.IndirectY);
				
			// SEC
			case 0x38:
				return SEC();
				
			// SED
			case 0xF8:
				return SED();
				
			// SEI
			case 0x78:
				return SEI();
			
			// SKB
			case 0x80, 0x82, 0x89, 0xC2, 0xE2:
				return SKB();
			
			// SLO
			case 0x0F:
				return SLO(.Absolute);
			case 0x1F:
				return SLO(.AbsoluteIndexedX);
			case 0x1B:
				return SLO(.AbsoluteIndexedY);
			case 0x07:
				return SLO(.ZeroPage);
			case 0x17:
				return SLO(.ZeroPageIndexedX);
			case 0x03:
				return SLO(.IndirectX);
			case 0x13:
				return SLO(.IndirectY);
			
			// SRE
			case 0x4F:
				return SRE(.Absolute);
			case 0x5F:
				return SRE(.AbsoluteIndexedX);
			case 0x5B:
				return SRE(.AbsoluteIndexedY);
			case 0x47:
				return SRE(.ZeroPage);
			case 0x57:
				return SRE(.ZeroPageIndexedX);
			case 0x43:
				return SRE(.IndirectX);
			case 0x53:
				return SRE(.IndirectY);
			
			// STA
			case 0x85:
				return STA(.ZeroPage);
			case 0x95:
				return STA(.ZeroPageIndexedX);
			case 0x8D:
				return STA(.Absolute);
			case 0x9D:
				return STA(.AbsoluteIndexedX);
			case 0x99:
				return STA(.AbsoluteIndexedY);
			case 0x81:
				return STA(.IndirectX);
			case 0x91:
				return STA(.IndirectY);
				
			// STX
			case 0x86:
				return STX(.ZeroPage);
			case 0x96:
				return STX(.ZeroPageIndexedY);
			case 0x8E:
				return STX(.Absolute);
				
			// STY
			case 0x84:
				return STY(.ZeroPage);
			case 0x94:
				return STY(.ZeroPageIndexedX);
			case 0x8C:
				return STY(.Absolute);
			
			// SXA
			case 0x9E:
				return SXA();
			
			// SYA
			case 0x9C:
				return SYA();
			
			// TAX
			case 0xAA:
				return TAX();
				
			// TAY
			case 0xA8:
				return TAY();
				
			// TSX
			case 0xBA:
				return TSX();
				
			// TXA
			case 0x8A:
				return TXA();
				
			// TXS
			case 0x9A:
				return TXS();
				
			// TYA
			case 0x98:
				return TYA();
			
			default:
				print("ERROR: Instruction with opcode 0x\(logger.hexString(opcode, padding: 2)) not found");
				self.errorOccured = true;
				return -1;
		}
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
    
    func readFromMemoryUsingAddressingMode(mode: AddressingMode) -> UInt8 {
        switch mode {
			case .Immediate:
				return fetchPC();
			default: break
        }
        
        return self.mainMemory.readMemory(addressUsingAddressingMode(mode));
    }
    
    func addressUsingAddressingMode(mode: AddressingMode) -> Int {
        switch mode {
			case AddressingMode.ZeroPage:
				return Int(fetchPC());
				
			case AddressingMode.ZeroPageIndexedX, .ZeroPageIndexedY:
				var index = self.X;
				
				if(mode == AddressingMode.ZeroPageIndexedY) {
					index = self.Y;
				}
				
				return (Int(fetchPC()) + Int(index)) & 0xFF;
				
			case AddressingMode.Absolute:
				let lowByte = fetchPC();
				let highByte = fetchPC();
				
				return address(lowByte, upper: highByte);
				
			case AddressingMode.AbsoluteIndexedX, .AbsoluteIndexedY:
				let lowByte = fetchPC();
				let highByte = fetchPC();
				
				var index = self.X;
				
				if(mode == AddressingMode.AbsoluteIndexedY) {
					index = self.Y;
				}
				
				let originalAddress = address(lowByte, upper: highByte);
				
				let newAddress = (Int(originalAddress) + Int(index)) & 0xFFFF;
				
				self.pageCrossed = !checkPage(UInt16(newAddress), originalAddress: UInt16(originalAddress));
				
				return newAddress;
				
			case AddressingMode.IndirectX:
				let immediate = fetchPC();
				
				let lowByte = self.mainMemory.readMemory(Int(UInt16(immediate) + UInt16(self.X)) & 0xFF);
				
				let highByte = self.mainMemory.readMemory(Int(UInt16(immediate) + UInt16(self.X) + 1) & 0xFF);
				
				return address(lowByte, upper: highByte);
				
			case AddressingMode.IndirectY:
				let immediate = fetchPC();
				
				let lowByte = self.mainMemory.readMemory(Int(immediate));
				let highByte = self.mainMemory.readMemory((Int(immediate) + 1) & 0xFF);
				
				let originalAddress = address(lowByte, upper: highByte);
				
				let newAddress = (Int(originalAddress) + Int(self.Y)) & 0xFFFF;
				
				self.pageCrossed = !checkPage(UInt16(newAddress), originalAddress: UInt16(originalAddress));
				
				return newAddress;
				
			default:
				print("Invalid AddressingMode on addressUsingAddressingMode");
				return 0;
        }
    }
	
	/**
	 Returns true if the address lies on the same page as PC
	*/
	func checkPage(address: UInt16) -> Bool {
		return checkPage(address, originalAddress: getPC());
	}
	
	/**
	 Returns true if the address lies on the same page as originalAddress
	*/
	func checkPage(address: UInt16, originalAddress: UInt16) -> Bool {
		return address / 0x100 == originalAddress / 0x100;
	}
	
	/**
	 Converts the given value to binary coded decimal, where
	 the first nibble is a tens place digit, and the second a
	 ones place digit
	*/
	func bcdValue(value: UInt8) -> UInt8 {
		let upper = (value >> 4) & 0xF;
		let lower = value & 0xF;
		
		return upper * 10 + lower;
	}
	
	/**
	 Sets a interrupt to trigger upon the next clock cycle
	*/
	func queueInterrupt(interrupt: Interrupt) {
		self.interrupt = interrupt;
	}
	
	/**
	 Handles the current interrupt
	*/
	func handleInterrupt() {
		let oldPCL = self.PCL;
		let oldPCH = self.PCH;
		
		var pMask: UInt8 = 0x10;
		
		switch self.interrupt! {
			case Interrupt.VBlank:
				setPC(self.mainMemory.readTwoBytesMemory(0xFFFA));
				// When performing a hardware interrupt, do not set the B flag
				pMask = 0x0;
			
			case Interrupt.RESET:
				reset();
				return;
			
			case Interrupt.Software:
				setPC(self.mainMemory.readTwoBytesMemory(0xFFFE));
		}
		
		push(oldPCH);
		push(oldPCL);
		
		push(self.P | pMask);
		
		self.interrupt = nil;
	}
	
	func startOAMTransfer() {
		self.oamTransfer = true;
		self.oamCycles = 0;
		
		if(self.evenCycle) {
			// Next cycle will not be even, so extra cycle
			self.oamExtraCycle = true;
		} else {
			self.oamExtraCycle = false;
		}
	}
	
    // MARK: - PC Operations
    func setPC(address: UInt16) {
        self.PCL = UInt8(address & 0xFF);
        self.PCH = UInt8((address & 0xFF00) >> 8);
    }
    
    func getPC() -> UInt16 {
        return UInt16(self.PCL) | (UInt16(self.PCH) << 8);
    }
    
    func incrementPC() {
        setPC(UInt16((Int(getPC()) + 1) & 0xFFFF));
    }
    
    func decrementPC() {
		setPC(UInt16((Int(getPC()) - 1) & 0xFFFF));
    }
    
    func fetchPC() -> UInt8 {
        let byte = self.mainMemory.readMemory(Int(getPC()));
        
        incrementPC();
        
        return byte;
    }
    
    // MARK: - Stack Operations
    func push(byte: UInt8) {
        self.mainMemory.writeMemory(0x100 + Int(self.SP), data: byte);
        
        if(self.SP == 0) {
            print("ERROR: Stack underflow");
			self.errorOccured = true;
			return;
        }
        
        self.SP = self.SP - 1;
    }
    
    func pop() -> UInt8 {
        if(self.SP == 0xFF) {
            print("ERROR: Stack overflow");
			self.errorOccured = true;
			return 0;
        }
        
        self.SP = self.SP + 1;
        
        return self.mainMemory.readMemory(0x100 + Int(self.SP));
    }
    
    // MARK: - Instructions
    // MARK: Stack
    
    /**
     Simulate Interrupt ReQuest (IRQ)
    */
    func BRK() -> Int {
		queueInterrupt(Interrupt.Software);
		
        return 7;
    }
    
    /**
     ReTurn from Interrupt
    */
    func RTI() -> Int {
        self.P = pop();
        self.PCL = pop();
        self.PCH = pop();
		
		// Force unused flag to be set
		setPBit(5, value: true);
        
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
		// Force break flag to be set
		setPBit(4, value: true);
		
        push(self.P);
		
		setPBit(4, value: false);
        
        return 3;
    }
    
    /**
     PulL from Stack to A
    */
    func PLA() -> Int {
        self.A = pop();
		
		// Set negative flag
		setPBit(7, value: (self.A >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.A == 0));
        
        return 4;
    }
    
    /**
     PulL from Stack to P
    */
    func PLP() -> Int {
        self.P = pop();
		
		// Ensure break flag is not set
		setPBit(4, value: false);
		
		// Ensure unused bit is set
		setPBit(5, value: true);
        
        return 4;
    }
    
    /**
     Jump to SubRoutine
    */
    func JSR() -> Int {
        let temp = getPC() + 1;
        
        push(UInt8((temp >> 8) & 0xFF));
        push(UInt8(temp & 0xFF));
        
        let lowByte = fetchPC();
        
        self.PCH = fetchPC();
        self.PCL = lowByte;
		
        return 6;
    }
	
	// MARK: Memory
	
	/**
	 Store A in Memory
	*/
	func STA(mode: AddressingMode) -> Int {
		var length = 5;
		
		switch mode {
			case .ZeroPage:
				length = 3;
				
			case .ZeroPageIndexedX, .Absolute:
				length = 4;
				
			case .AbsoluteIndexedX, .AbsoluteIndexedY:
				length = 5;
			
			case .IndirectX, .IndirectY:
				length = 6;
			
			default:
				print("Invalid AddressingMode on STA");
				return -1;
		}
		
		let address = addressUsingAddressingMode(mode);
		
		self.pageCrossed = false;
		
		self.mainMemory.writeMemory(address, data: self.A);
		
		return length;
	}
	
	/**
	 Store X in Memory
	*/
	func STX(mode: AddressingMode) -> Int {
		var length = 4;
		
		switch mode {
			case .ZeroPage:
				length = 3;
				
			case .ZeroPageIndexedY, .Absolute:
				length = 4;
				
			default:
				print("Invalid AddressingMode on STX");
				return -1;
		}
		
		let address = addressUsingAddressingMode(mode);
		
		self.pageCrossed = false;
		
		self.mainMemory.writeMemory(address, data: self.X);
		
		return length;
	}
	
	/**
	 Store Y in Memory
	*/
	func STY(mode: AddressingMode) -> Int {
		var length = 4;
		
		switch mode {
			case .ZeroPage:
				length = 3;
				
			case .ZeroPageIndexedX, .Absolute:
				length = 4;
				
			default:
				print("Invalid AddressingMode on STY");
				return -1;
		}
		
		let address = addressUsingAddressingMode(mode);
		
		self.pageCrossed = false;
		
		self.mainMemory.writeMemory(address, data: self.Y);
		
		return length;
	}
	
	/**
	 Store A AND X in Memory (unofficial)
	*/
	func SAX(mode: AddressingMode) -> Int {
		var length = 4;
		
		switch mode {
			case .Absolute:
				length = 4;
			case .ZeroPage:
				length = 3;
			case .IndirectX:
				length = 6;
			case .ZeroPageIndexedY:
				length = 4;
			default:
				print("Invalid AddressingMode on SAX");
		}
		
		let address = addressUsingAddressingMode(mode);
		
		self.mainMemory.writeMemory(address, data: self.A & self.X);
		
		return length;
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
	 Load A and X from Memory (unofficial)
	*/
	func LAX(mode: AddressingMode) -> Int {
		switch mode {
			case .ZeroPage, .ZeroPageIndexedY,
				 .Absolute, .AbsoluteIndexedY,
				 .IndirectX, .IndirectY:
				let temp = LOAD(mode, register: &self.A);
				self.X = self.A;
				return temp;
		default:
			print("Invalid AddressingMode on LAX");
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
				
			case AddressingMode.ZeroPage:
				length = 3;
				
			case AddressingMode.IndirectX:
				length = 6;
				
			case AddressingMode.IndirectY:
				length = 5;
				
			case AddressingMode.ZeroPageIndexedX, .ZeroPageIndexedY,
				 .Absolute, .AbsoluteIndexedX, .AbsoluteIndexedY:
				length = 4;
				
			default:
				print("Invalid AddressingMode on LOAD");
				return -1;
		}
		
		register.memory = readFromMemoryUsingAddressingMode(mode);
		
		// Set negative flag
		setPBit(7, value: (register.memory >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (register.memory == 0));
		
		return length;
	}
	
	/**
	 Transfer A to X
	*/
	func TAX() -> Int {
		self.X = self.A;
		
		// Set negative flag
		setPBit(7, value: (self.X >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.X == 0));
		
		return 2;
	}
	
	/**
	 Transfer A to Y
	*/
	func TAY() -> Int {
		self.Y = self.A;
		
		// Set negative flag
		setPBit(7, value: (self.Y >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.Y == 0));
		
		return 2;
	}
	
	/**
	 Transfer Stack Pointer to X
	*/
	func TSX() -> Int {
		self.X = self.SP;
		
		// Set negative flag
		setPBit(7, value: (self.X >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.X == 0));
		
		return 2;
	}
	
	/**
	 Transfer X to A
	*/
	func TXA() -> Int {
		self.A = self.X;
		
		// Set negative flag
		setPBit(7, value: (self.A >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.A == 0));
		
		return 2;
	}
	
	/**
	 Transfer X to SP
	*/
	func TXS() -> Int {
		self.SP = self.X;
		
		return 2;
	}
	
	/**
	 Transfer Y to A
	*/
	func TYA() -> Int {
		self.A = self.Y;
		
		// Set negative flag
		setPBit(7, value: (self.A >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.A == 0));
		
		return 2;
	}
	
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
				let lowerByte = UInt16(fetchPC());
				let higherByte = UInt16(fetchPC()) << 8;
				
                self.PCL = self.mainMemory.readMemory(Int(lowerByte | higherByte));
				// Add 1 only to lower byte due to CPU bug
                self.PCH = self.mainMemory.readMemory(Int(((UInt16(lowerByte) + 1) & 0xFF) | higherByte));
            default:
                print("Invalid AddressingMode on JMP");
        }
        
        return 3;
    }
	
    // MARK: Math
    
    /**
     Add Memory to A with Carry
    */
    func ADC(mode: AddressingMode) -> Int {
		var length = 4;
		
		let memoryValue = readFromMemoryUsingAddressingMode(mode);
		
		switch mode {
			case .Immediate:
				length = 2;
				
			case .ZeroPage:
				length = 3;
				
			case .ZeroPageIndexedX, .Absolute, .AbsoluteIndexedX, .AbsoluteIndexedY:
				length = 4;
				
			case .IndirectX:
				length = 6;
				
			case .IndirectY:
				length = 5;
				
			default:
				print("Invalid AddressingMode on ADC");
				return -1;
		}
		
		let temp = UInt16(self.A) + UInt16(memoryValue) + (getPBit(0) ? 1 : 0);
		
		// Set overflow flag
		setPBit(6, value: (~(self.A ^ memoryValue) & (self.A ^ UInt8(temp & 0xFF)) & 0x80) == 0x80);
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1);
		
		// Set zero flag
		setPBit(1, value: (temp & 0xFF) == 0);
		
		// Decimal mode not supported by NES CPU
		// Decimal flag
		/*if(getPBit(3)) {
			temp = UInt16(bcdValue(self.A)) + UInt16(bcdValue(memoryValue)) + (getPBit(0) ? 1 : 0);
			
			// Set carry flag
			setPBit(0, value: temp > 99);
		} else {*/
		
		// Set carry flag
		setPBit(0, value: temp > 255);
		
		self.A = UInt8(temp & 0xFF);
		
		return length;
    }
    
    /**
     Subtract Memory to A with Borrow
    */
    func SBC(mode: AddressingMode) -> Int {
		var length = 4;
		
		switch mode {
			case .Immediate:
				length = 2;
				
			case .ZeroPage:
				length = 3;
				
			case .ZeroPageIndexedX, .Absolute, .AbsoluteIndexedX, .AbsoluteIndexedY:
				length = 4;
				
			case .IndirectX:
				length = 6;
				
			case .IndirectY:
				length = 5;
				
			default:
				print("Invalid AddressingMode on SBC");
				return -1;
		}
		
		let memoryValue = readFromMemoryUsingAddressingMode(mode);
		
		var temp: Int;
		
		// Decimal mode not supported by NES CPU
		// Decimal flag
		/*if(getPBit(3)) {
			temp = Int(bcdValue(self.A)) - Int(bcdValue(memoryValue)) - (getPBit(0) ? 0 : 1);
			
			// Set overflow flag
			setPBit(6, value: (temp > 99) || (temp < 0));
		} else {*/
		
		temp = Int(self.A) - Int(memoryValue) - (getPBit(0) ? 0 : 1);
		
		// Set overflow flag
		setPBit(6, value: ((self.A ^ memoryValue) & (self.A ^ UInt8(temp & 0xFF)) & 0x80) == 0x80);
		
		// Set carry flag
		setPBit(0, value: temp >= 0);
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1);
		
		// Set zero flag
		setPBit(1, value: (temp & 0xFF) == 0);
		
		self.A = UInt8(temp & 0xFF);
		
        return length;
    }
	
	/**
	 Increment Memory
	*/
	func INC(mode: AddressingMode) -> Int {
		var length = 6;
		
		switch mode {
			case .ZeroPage:
				length = 5;
			
			case .ZeroPageIndexedX, .Absolute:
				length = 6;
			
			case .AbsoluteIndexedX:
				length = 7;
			
			default:
				print("Invalid AddressingMode on INC");
				return -1;
		}
		
		let address = addressUsingAddressingMode(mode);
		
		self.pageCrossed = false;
		
		var value = Int(self.mainMemory.readMemory(address));
		
		value = value + 1;
		
		// Set negative flag
		setPBit(7, value: (value >> 7) & 0x1 == 1);
		
		// Set zero flag
		setPBit(1, value: ((value & 0xFF) == 0));
		
		self.mainMemory.writeMemory(address, data: UInt8(value & 0xFF));
		
		return length;
	}
	
	/**
	 Increment X
	*/
	func INX() -> Int {
		self.X = UInt8((Int(self.X) + 1) & 0xFF);
		
		// Set negative flag
		setPBit(7, value: (self.X >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.X == 0));
		
		return 2;
	}
	
	/**
	 Increment Y
	*/
	func INY() -> Int {
		self.Y = UInt8((Int(self.Y) + 1) & 0xFF);
		
		// Set negative flag
		setPBit(7, value: (self.Y >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.Y == 0));
		
		return 2;
	}
	
	/**
	 Increment Memory then SBC (unofficial)
	*/
	func ISC(mode: AddressingMode) -> Int {
		var length = 6;
		
		switch mode {
			case .Absolute, .ZeroPageIndexedX:
				length = 6;
			case .ZeroPage:
				length = 5;
			case .AbsoluteIndexedX, .AbsoluteIndexedY:
				length = 7;
			case .IndirectX, .IndirectY:
				length = 8;
			default:
				print("Invalid AddressingMode on ISC");
				return -1;
		}
		
		let address = addressUsingAddressingMode(mode);
		var value = Int(self.mainMemory.readMemory(address));
		
		value = value + 1;
		
		let temp = Int(self.A) - Int(value & 0xFF) - (getPBit(0) ? 0 : 1);
		
		// Set overflow flag
		setPBit(6, value: ((self.A ^ UInt8(value & 0x80)) & (self.A ^ UInt8(temp & 0xFF)) & 0x80) == 0x80);
		
		// Set carry flag
		setPBit(0, value: temp >= 0);
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1);
		
		// Set zero flag
		setPBit(1, value: (temp & 0xFF) == 0);
		
		self.A = UInt8(temp & 0xFF);
		
		self.mainMemory.writeMemory(address, data: UInt8(value & 0xFF));
		
		return length;
	}
	
	/**
	 Decrement Memory then CMP (unofficial)
	*/
	func DCP(mode: AddressingMode) -> Int {
		var length = 6;
		
		switch mode {
			case .Absolute, .ZeroPageIndexedX:
				length = 6;
			case .ZeroPage:
				length = 5;
			case .AbsoluteIndexedX, .AbsoluteIndexedY:
				length = 7;
			case .IndirectX, .IndirectY:
				length = 8;
			default:
				print("Invalid AddressingMode on DCP");
				return -1;
		}
		
		let address = addressUsingAddressingMode(mode);
		var value = Int(self.mainMemory.readMemory(address));
		
		value = value - 1;
		
		let temp = Int(self.A) - value;
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1);
		
		// Set zero flag
		setPBit(1, value: ((temp & 0xFF) == 0));
		
		// Set carry flag
		setPBit(0, value: (UInt8(self.A & 0xFF) >= UInt8(value & 0xFF)));
		
		self.mainMemory.writeMemory(address, data: UInt8(value & 0xFF));
		
		return length;
	}
	
	/**
	 Decrement Memory
	*/
	func DEC(mode: AddressingMode) -> Int {
		var length = 6;
		
		switch mode {
			case .ZeroPage:
				length = 5;
				
			case .ZeroPageIndexedX, .Absolute:
				length = 6;
				
			case .AbsoluteIndexedX:
				length = 7;
				
			default:
				print("Invalid AddressingMode on DEC");
				return -1;
		}
		
		let address = addressUsingAddressingMode(mode);
		
		self.pageCrossed = false;
		
		var value = Int(self.mainMemory.readMemory(address));
		
		value = value - 1;
		
		// Set negative flag
		setPBit(7, value: (value >> 7) & 0x1 == 1);
		
		// Set zero flag
		setPBit(1, value: ((value & 0xFF) == 0));
		
		self.mainMemory.writeMemory(address, data: UInt8(value & 0xFF));
		
		return length;
	}
	
	/**
	 Decrement X
	*/
	func DEX() -> Int {
		self.X = UInt8((Int(self.X) - 1) & 0xFF);
		
		// Set negative flag
		setPBit(7, value: (self.X >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.X == 0));
		
		return 2;
	}
	
	/**
	 Decrement Y
	*/
	func DEY() -> Int {
		self.Y = UInt8((Int(self.Y) - 1) & 0xFF);
		
		// Set negative flag
		setPBit(7, value: (self.Y >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.Y == 0));
		
		return 2;
	}
	
    /**
     Arithmetic Shift Left
    */
    func ASL(mode: AddressingMode) -> Int {
        var length = 6;
        
        switch mode {
            case .Accumulator:
                length = 2;
            
            case .ZeroPage:
                length = 5;
                
            case .ZeroPageIndexedX, .Absolute:
                length = 6;
                
            case .AbsoluteIndexedX:
                length = 7;
                
            default:
                print("Invalid AddressingMode on ASL");
                return -1;
        }
        
        if(mode == .Accumulator) {
            // Set carry flag
            setPBit(0, value: (self.A >> 7) == 1);
            
            self.A = (self.A << 1) & 0xFE;
            
            // Set negative flag
            setPBit(7, value: (self.A >> 7) == 1);
            
            // Set zero flag
            setPBit(1, value: (self.A == 0));
        } else {
            let address = addressUsingAddressingMode(mode);
			
			self.pageCrossed = false;
			
            let value = self.mainMemory.readMemory(address);
            
            // Set carry flag
            setPBit(0, value: (value >> 7) == 1);
            
            let temp = (value << 1) & 0xFE;
            
            // Set negative flag
            setPBit(7, value: (temp >> 7) == 1);
            
            // Set zero flag
            setPBit(1, value: (temp == 0));
            
            self.mainMemory.writeMemory(address, data: temp);
        }
        
        return length;
    }
	
	/**
	 Shift Left and ORA (unofficial)
	*/
	func SLO(mode: AddressingMode) -> Int {
		var length = 6;
		
		switch mode {
			case .Absolute, .ZeroPageIndexedX:
				length = 6;
				
			case .ZeroPage:
				length = 5;
				
			case .AbsoluteIndexedX, .AbsoluteIndexedY:
				length = 7;
				
			case .IndirectX, .IndirectY:
				length = 8;
				
			default:
				print("Invalid AddressingMode on SLO");
				return -1;
		}
		
		let address = addressUsingAddressingMode(mode);
		let value = self.mainMemory.readMemory(address);
		
		// Set carry flag
		setPBit(0, value: (value >> 7) == 1);
		
		let temp = (value << 1) & 0xFE;
		
		self.A = self.A | temp;
		
		// Set negative flag
		setPBit(7, value: (self.A >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.A == 0));
		
		self.mainMemory.writeMemory(address, data: temp);
		
		return length;
	}
	
    /**
     Logical Shift Right
    */
    func LSR(mode: AddressingMode) -> Int {
        var length = 6;
		
        switch mode {
            case .Accumulator:
                length = 2;
                
            case .ZeroPage:
                length = 5;
                
            case .ZeroPageIndexedX, .Absolute:
                length = 6;
                
            case .AbsoluteIndexedX:
                length = 7;
                
            default:
                print("Invalid AddressingMode on LSR");
                return -1;
        }
        
        if(mode == .Accumulator) {
            // Set negative flag
            setPBit(7, value: false);
            
            // Set carry flag
            setPBit(0, value: (self.A & 0x1) == 1);
            
            self.A = (self.A >> 1) & 0x7F;
            
            // Set zero flag
            setPBit(1, value: (self.A == 0));
        } else {
            let address = addressUsingAddressingMode(mode);
			
			self.pageCrossed = false;
			
            let value = self.mainMemory.readMemory(address);
            
            // Set negative flag
            setPBit(7, value: false);
            
            // Set carry flag
            setPBit(0, value: (value & 0x1) == 1);
            
            let temp = (value >> 1) & 0x7F;
            
            // Set zero flag
            setPBit(1, value: (temp == 0));
            
            self.mainMemory.writeMemory(address, data: temp);
        }
        
        return length;
    }
	
	/**
	 Logical Shift Right and EOR (unofficial)
	*/
	func SRE(mode: AddressingMode) -> Int {
		var length = 6;
		
		switch mode {
			case .Absolute, .ZeroPageIndexedX:
				length = 6;
				
			case .ZeroPage:
				length = 5;
				
			case .AbsoluteIndexedX, .AbsoluteIndexedY:
				length = 7;
				
			case .IndirectX, .IndirectY:
				length = 8;
				
			default:
				print("Invalid AddressingMode on SRE");
				return -1;
		}
		
		let address = addressUsingAddressingMode(mode);
		let value = self.mainMemory.readMemory(address);
		
		// Set carry flag
		setPBit(0, value: (value & 0x1) == 1);
		
        // TODO: Possibly incorrect (seems to pass tests though)
		let temp = (value >> 1) & 0x7F;
		
		self.A = self.A ^ temp;
		
		// Set negative flag
		setPBit(7, value: (self.A >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.A == 0));
		
		self.mainMemory.writeMemory(address, data: temp);
		
		return length;
	}
	
    /**
     ROtate Left
    */
    func ROL(mode: AddressingMode) -> Int {
        var length = 6;
		
        switch mode {
            case .Accumulator:
                length = 2;
                
            case .ZeroPage:
                length = 5;
                
            case .ZeroPageIndexedX, .Absolute:
                length = 6;
                
            case .AbsoluteIndexedX:
                length = 7;
                
            default:
                print("Invalid AddressingMode on ROL");
                return -1;
        }
        
        if(mode == .Accumulator) {
            let carry = (self.A >> 7) & 0x1;
            
            self.A = (self.A << 1) & 0xFE;
            self.A = self.A | (getPBit(0) ? 1:0);
			
			// Set carry flag
			setPBit(0, value: carry == 1);
			
			// Set zero flag
			setPBit(1, value: (self.A == 0));
			
            // Set negative flag
            setPBit(7, value: (self.A >> 7) & 0x1 == 1);
        } else {
            let address = addressUsingAddressingMode(mode);
			
			self.pageCrossed = false;
			
            var value = self.mainMemory.readMemory(address);
			
			let carry = (value >> 7) & 0x1;
			value = (value << 1) & 0xFE;
			value = value | (getPBit(0) ? 1:0);
            
			// Set carry flag
			setPBit(0, value: carry == 1);
			
			// Set zero flag
			setPBit(1, value: (value == 0));
			
			// Set negative flag
			setPBit(7, value: (value >> 7) & 0x1 == 1);
			
            self.mainMemory.writeMemory(address, data: value);
        }
        
        return length;
    }
	
	/**
	 ROtate Right
	*/
	func ROR(mode: AddressingMode) -> Int {
		var length = 6;
		
		switch mode {
			case .Accumulator:
				length = 2;
				
			case .ZeroPage:
				length = 5;
				
			case .ZeroPageIndexedX, .Absolute:
				length = 6;
				
			case .AbsoluteIndexedX:
				length = 7;
				
			default:
				print("Invalid AddressingMode on ROR");
				return -1;
		}
		
		if(mode == .Accumulator) {
			let carry = self.A & 0x1;
			
			self.A = (self.A >> 1) & 0x7F;
			self.A = self.A | (getPBit(0) ? 0x80 : 0);
			
			// Set carry flag
			setPBit(0, value: carry == 1);
			
			// Set zero flag
			setPBit(1, value: (self.A == 0));
			
			// Set negative flag
			setPBit(7, value: (self.A >> 7) & 0x1 == 1);
		} else {
			let address = addressUsingAddressingMode(mode);
			
			self.pageCrossed = false;
			
			var value = self.mainMemory.readMemory(address);
			
			let carry = value & 0x1;
			value = (value >> 1) & 0x7F;
			value = value | (getPBit(0) ? 0x80 : 0);
			
			// Set carry flag
			setPBit(0, value: carry == 1);
			
			// Set zero flag
			setPBit(1, value: (value == 0));
			
			// Set negative flag
			setPBit(7, value: (value >> 7) & 0x1 == 1);
			
			self.mainMemory.writeMemory(address, data: value);
		}
		
		return length;
	}
	
	/**
	 ROtate Left and AND (unofficial)
	*/
	func RLA(mode: AddressingMode) -> Int {
		var length = 6;
		
		switch mode {
			case .ZeroPage:
				length = 5;
				
			case .ZeroPageIndexedX, .Absolute:
				length = 6;
				
			case .AbsoluteIndexedX, .AbsoluteIndexedY:
				length = 7;
			
			case .IndirectX, .IndirectY:
				length = 8;
			
			default:
				print("Invalid AddressingMode on RLA");
				return -1;
		}
		
		let address = addressUsingAddressingMode(mode);
		var value = self.mainMemory.readMemory(address);
		
		let carry = (value >> 7) & 0x1;
		value = (value << 1) & 0xFE;
		value = value | (getPBit(0) ? 1:0);
		
		// Set carry flag
		setPBit(0, value: carry == 1);
		
		self.A = self.A & value;
		
		// Set negative flag
		setPBit(7, value: (self.A >> 7) == 1);
		
		// Set zero flag
		setPBit(1, value: (self.A == 0));
		
		self.mainMemory.writeMemory(address, data: value);
		
		return length;
	}
    
    /**
     ROtate Right and Add (unofficial)
    */
    func RRA(mode: AddressingMode) -> Int {
        var length = 6;
        
        switch mode {
            case .ZeroPage:
                length = 5;
                
            case .ZeroPageIndexedX, .Absolute:
                length = 6;
                
            case .AbsoluteIndexedX, .AbsoluteIndexedY:
                length = 7;
                
            case .IndirectX, .IndirectY:
                length = 8;
                
            default:
                print("Invalid AddressingMode on RRA");
                return -1;
        }
        
        let address = addressUsingAddressingMode(mode);
        var value = self.mainMemory.readMemory(address);
        
        let carry = value & 0x1;
        value = (value >> 1) & 0x7F;
        value = value | (getPBit(0) ? 0x80 : 0);
        
        let temp = UInt16(self.A) + UInt16(value) + UInt16(carry);
        
        // Set overflow flag
        setPBit(6, value: (~(self.A ^ value) & (self.A ^ UInt8(temp & 0xFF)) & 0x80) == 0x80);
        
        // Set negative flag
        setPBit(7, value: ((temp >> 7) & 0x1) == 1);
        
        // Set zero flag
        setPBit(1, value: (temp & 0xFF) == 0);
        
        // Set carry flag
        setPBit(0, value: temp > 255);
        
        self.A = UInt8(temp & 0xFF);
        
        self.mainMemory.writeMemory(address, data: value);
        
        return length;
    }
	
    // MARK: Logical
	
    /**
     Bitwise XOR A with Memory
    */
    func EOR(mode: AddressingMode) -> Int {
        var length = 4;
		
        switch mode {
            case .Immediate:
                length = 2;
			
            case .ZeroPage:
                length = 3;
			
            case .ZeroPageIndexedX, .Absolute, .AbsoluteIndexedX,
                 .AbsoluteIndexedY:
                length = 4;
            
            case .IndirectX:
                length = 6;
            
            case .IndirectY:
                length = 5;
            
            default:
                print("Invalid AddressingMode on EOR");
                return -1;
        }
        
        self.A = self.A ^ readFromMemoryUsingAddressingMode(mode);
        
        // Set negative flag
        setPBit(7, value: (self.A >> 7) == 1);
        
        // Set zero flag
        setPBit(1, value: (self.A == 0));
        
        return length;
    }
    
    /**
     Bitwise AND A with Memory
    */
    func AND(mode: AddressingMode) -> Int {
        var length = 4;
        
        switch mode {
            case .Immediate, .ZeroPage:
                length = 2;
            
            case .ZeroPageIndexedX:
                length = 3;
            
            case .Absolute, .AbsoluteIndexedX, .AbsoluteIndexedY:
                length = 4;
            
            case .IndirectX:
                length = 6;
            
            case .IndirectY:
                length = 5;
            
            default:
                print("Invalid AddressingMode on AND");
                return -1;
        }
		
        self.A = self.A & readFromMemoryUsingAddressingMode(mode);
		
        // Set negative flag
        setPBit(7, value: (self.A >> 7) == 1);
        
        // Set zero flag
        setPBit(1, value: (self.A == 0));
        
        return length;
    }
    
    /**
     Bitwise OR A with Memory
    */
    func ORA(mode: AddressingMode) -> Int {
        var length = 4;
        
        switch mode {
            case .Immediate, .ZeroPage:
                length = 2;
                
            case .ZeroPageIndexedX:
                length = 3;
                
            case .Absolute, .AbsoluteIndexedX, .AbsoluteIndexedY:
                length = 4;
                
            case .IndirectX:
                length = 6;
                
            case .IndirectY:
                length = 5;
                
            default:
                print("Invalid AddressingMode on ORA");
                return -1;
        }
        
        self.A = self.A | readFromMemoryUsingAddressingMode(mode);
        
        // Set negative flag
        setPBit(7, value: (self.A >> 7) == 1);
        
        // Set zero flag
        setPBit(1, value: (self.A == 0));
        
        return length;
    }
	
	/**
	 AND immediate with A (unofficial)
	*/
	func ANC() -> Int {
		self.A = self.A & readFromMemoryUsingAddressingMode(.Immediate);
		
		// Set negative flag
		let negative = (self.A >> 7) & 0x1 == 1;
		setPBit(7, value: negative);
		
		// Set zero flag
		setPBit(1, value: (self.A == 0));
		
		// Set carry flag (if negative)
		setPBit(0, value: negative);
		
		return 2;
	}
	
	/**
	 AND immediate with A, then shift right 1 (unofficial)
	*/
	func ALR() -> Int {
		AND(.Immediate);
		LSR(.Accumulator);
		
		return 2;
	}
	
	/**
	 AND immediate with A, then rotate right 1 (unofficial)
	*/
	func ARR() -> Int {
		AND(.Immediate);
		ROR(.Accumulator);
		
		let bit5 = (self.A >> 5) & 0x1 == 1;
		let bit6 = (self.A >> 6) & 0x1 == 1;
		
		if(bit5) {
			if(bit6) {
				// Set carry flag
				setPBit(0, value: true);
				
				// Clear overflow flag
				setPBit(6, value: false);
			} else {
				// Clear carry flag
				setPBit(0, value: false);
				
				// Set overflow flag
				setPBit(6, value: true);
			}
		} else if(bit6) {
			// Set carry flag
			setPBit(0, value: true);
			
			// Set overflow flag
			setPBit(6, value: true);
		} else {
			// Clear carry flag
			setPBit(0, value: false);
			
			// Clear overflow flag
			setPBit(6, value: false);
		}
		
		return 2;
	}
	
	/**
	 AND immediate with A, then transfer A to X (unofficial)
	*/
	func LXA() -> Int {
		let immediate = readFromMemoryUsingAddressingMode(.Immediate);
		
		self.A = immediate;
		self.X = immediate;
		
		// Set zero flag
		setPBit(1, value: (self.A == 0));
		
		// Set negative flag
		setPBit(7, value: (self.A >> 7) & 0x1 == 1);
		
		return 2;
	}
	
	/**
	 AND X with A, then subtract immediate from X (unofficial)
	*/
	func AXS() -> Int {
		self.X = self.A & self.X;
		
		let memoryValue = readFromMemoryUsingAddressingMode(.Immediate);
		
		let temp = Int(self.X) - Int(memoryValue);
		
		// Set carry flag
		setPBit(0, value: temp >= 0);
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1);
		
		// Set zero flag
		setPBit(1, value: (temp & 0xFF) == 0);
		
		self.X = UInt8(temp & 0xFF);
		
		return 2;
	}
	
	/**
	 AND X with high byte from Memory
	*/
	func SXA() -> Int {
		let address = addressUsingAddressingMode(.AbsoluteIndexedY);
		
		let high = self.X & UInt8(((address >> 8) + Int(1)) & 0xFF);
		
		self.mainMemory.writeMemory((Int(high) << 8) | (address & 0xFF), data: self.X);
		
		return 2;
	}
	
	/**
	 AND Y with high byte from Memory
	*/
	func SYA() -> Int {
		let address = addressUsingAddressingMode(.AbsoluteIndexedX);
		
		let high = self.Y & UInt8(((address >> 8) + Int(1)) & 0xFF);
		
		self.mainMemory.writeMemory((Int(high) << 8) | (address & 0xFF), data: self.Y);
		
		return 2;
	}
	
    // MARK: Flow Control
	
    /**
     Compare A with Memory
    */
    func CMP(mode: AddressingMode) -> Int {
        var length = 4;
		
        switch mode {
            case .Immediate:
                length = 2;
			
            case .ZeroPage:
                length = 3;
            
            case .ZeroPageIndexedX, .Absolute, .AbsoluteIndexedX, .AbsoluteIndexedY:
                length = 4;
                
            case .IndirectX:
                length = 6;
                
            case .IndirectY:
                length = 5;
                
            default:
                print("Invalid AddressingMode on CMP");
                return -1;
        }
        
        let mem = readFromMemoryUsingAddressingMode(mode);
        let temp = Int(self.A) - Int(mem);
        
        // Set negative flag
        setPBit(7, value: ((temp >> 7) & 0x1) == 1);
        
        // Set zero flag
        setPBit(1, value: (temp == 0));
        
        // Set carry flag
        setPBit(0, value: (self.A >= mem));
        
        return length;
    }
    
    /**
     Test bits in A with Memory
    */
    func BIT(mode: AddressingMode) -> Int {
        var length = 3;
        
        switch mode {
			case .ZeroPage:
				length = 3;
				
			case .Absolute:
				length = 4;
				
			default:
				print("Invalid AddressingMode on BIT");
				return -1;
        }
        
        let mem = readFromMemoryUsingAddressingMode(mode);
        let temp = self.A & mem;
		
        // Set negative flag
        setPBit(7, value: (mem >> 7) == 1);
        
        // Set overflow flag
        setPBit(6, value: ((mem >> 6) & 0x1) == 1);
		
        // Set zero flag
        setPBit(1, value: (temp == 0));
        
        return length;
    }
	
	/**
	 Branch if Carry flag is Clear
	*/
	func BCC() -> Int {
        let relative = UInt16(fetchPC());
        
		if(!getPBit(0)) {
			let newPC = UInt16((Int(getPC()) + (Int(relative) ^ 0x80) - 0x80) & 0xFFFF);
			
			let cycles = checkPage(newPC) ? 3 : 4;
			
			setPC(newPC);
			return cycles;

		}
		
		return 2;
	}
	
	/**
	 Branch if Carry flag is Set
	*/
	func BCS() -> Int {
        let relative = UInt16(fetchPC());
        
		if(getPBit(0)) {
			let newPC = UInt16((Int(getPC()) + (Int(relative) ^ 0x80) - 0x80) & 0xFFFF);
			
			let cycles = checkPage(newPC) ? 3 : 4;
			
			setPC(newPC);
			return cycles;

		}
		
		return 2;
	}
	
	/**
	 Branch if Zero flag is Set
	*/
	func BEQ() -> Int {
        let relative = UInt16(fetchPC());
        
		if(getPBit(1)) {
			let newPC = UInt16((Int(getPC()) + (Int(relative) ^ 0x80) - 0x80) & 0xFFFF);
			
			let cycles = checkPage(newPC) ? 3 : 4;
			
			setPC(newPC);
			return cycles;
		}
		
		return 2;
	}
	
	/**
	 Branch if negative flag is set
	*/
	func BMI() -> Int {
        let relative = UInt16(fetchPC());
        
		if(getPBit(7)) {
			let newPC = UInt16((Int(getPC()) + (Int(relative) ^ 0x80) - 0x80) & 0xFFFF);
			
			let cycles = checkPage(newPC) ? 3 : 4;
			
			setPC(newPC);
			return cycles;
		}
		
		return 2;
	}
	
	/**
	 Branch if zero flag is clear
	*/
	func BNE() -> Int {
        let relative = UInt16(fetchPC());
        
		if(!getPBit(1)) {
			let newPC = UInt16((Int(getPC()) + (Int(relative) ^ 0x80) - 0x80) & 0xFFFF);
			
			let cycles = checkPage(newPC) ? 3 : 4;
			
			setPC(newPC);
			return cycles;
		}
		
		return 2;
	}
	
	/**
	 Branch if negative flag is clear
	*/
	func BPL() -> Int {
        let relative = UInt16(fetchPC());
        
		if(!getPBit(7)) {
			let newPC = UInt16((Int(getPC()) + (Int(relative) ^ 0x80) - 0x80) & 0xFFFF);
			
			let cycles = checkPage(newPC) ? 3 : 4;
			
			setPC(newPC);
			return cycles;
		}
		
		return 2;
	}
	
	/**
	 Branch if oVerflow flag is Clear
	*/
	func BVC() -> Int {
        let relative = UInt16(fetchPC());
        
		if(!getPBit(6)) {
			let newPC = UInt16((Int(getPC()) + (Int(relative) ^ 0x80) - 0x80) & 0xFFFF);
			
			let cycles = checkPage(newPC) ? 3 : 4;
			
			setPC(newPC);
			return cycles;
		}
		
		return 2;
	}
	
	/**
	 Branch if oVerflow flag is Set
	*/
	func BVS() -> Int {
        let relative = UInt16(fetchPC());
        
		if(getPBit(6)) {
			let newPC = UInt16((Int(getPC()) + (Int(relative) ^ 0x80) - 0x80) & 0xFFFF);
			
			let cycles = checkPage(newPC) ? 3 : 4;
			
			setPC(newPC);
			return cycles;
		}
		
		return 2;
	}
	
	/**
	 ComPare X with Memory
	*/
	func CPX(mode: AddressingMode) -> Int {
		var length = 3;
		
		switch mode {
			case .Immediate:
				length = 2;
			
			case .ZeroPage:
				length = 3;
				
			case .Absolute:
				length = 4;
				
			default:
				print("Invalid AddressingMode on CPX");
				return -1;
		}
		
		let mem = readFromMemoryUsingAddressingMode(mode);
		let temp = Int(self.X) - Int(mem);
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1);
		
		// Set carry flag
		setPBit(0, value: self.X >= mem);
		
		// Set zero flag
		setPBit(1, value: (temp == 0));
		
		return length;
	}
	
	/**
	 ComPare Y with Memory
	*/
	func CPY(mode: AddressingMode) -> Int {
		var length = 3;
		
		switch mode {
			case .Immediate:
				length = 2;
				
			case .ZeroPage:
				length = 3;
				
			case .Absolute:
				length = 4;
				
			default:
				print("Invalid AddressingMode on CPY");
				return -1;
		}
		
		let mem = readFromMemoryUsingAddressingMode(mode);
		let temp = Int(self.Y) - Int(mem);
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1);
		
		// Set carry flag
		setPBit(0, value: self.Y >= mem);
		
		// Set zero flag
		setPBit(1, value: (temp == 0));
		
		return length;
	}
	
    /**
     No OPeration
    */
    func NOP() -> Int {
        return 2;
    }
	
	/**
	 Does nothing.  Is supposed to read from memory
	 at the specified address, but is used as a longer
	 NOP here
	*/
	func IGN(mode: AddressingMode) -> Int {
		fetchPC();
		
		switch mode {
			case .Absolute, .AbsoluteIndexedX:
				fetchPC();
				return 4;
			case .ZeroPage:
				return 3;
			case .ZeroPageIndexedX:
				return 4;
			default:
				print("Invalid AddressingMode on IGN");
				return -1;
		}
	}
	
	/**
	 Does nothing.  A NOP that reads the immediate byte
	*/
	func SKB() -> Int {
		fetchPC();
		
		return 2;
	}
	
	// MARK: P Register
	
	/**
	 Clear Carry flag
	*/
	func CLC() -> Int {
		setPBit(0, value: false);
		
		return 2;
	}
	
	/**
	 Clear Decimal flag
	*/
	func CLD() -> Int {
		setPBit(3, value: false);
		
		return 2;
	}
	
	/**
	 Clear Interrupt flag
	*/
	func CLI() -> Int {
		setPBit(2, value: false);
		
		return 2;
	}
	
	/**
	 Clear oVerflow flag
	*/
	func CLV() -> Int {
		setPBit(6, value: false);
		
		return 2;
	}
	
	/**
	 Set Carry flag
	*/
	func SEC() -> Int {
		setPBit(0, value: true);
		
		return 2;
	}
	
	/**
	 Set Decimal flag
	*/
	func SED() -> Int {
		setPBit(3, value: true);
		
		return 2;
	}
	
	/**
	 Set Interrupt flag
	*/
	func SEI() -> Int {
		setPBit(2, value: true);
		
		return 2;
	}
}