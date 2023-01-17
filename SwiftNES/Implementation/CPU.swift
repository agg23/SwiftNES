//
//  CPU.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class CPU: NSObject {

	// MARK: Registers

	/**
	 Lower Half of PC
	*/
	private var PCL: UInt8

	/**
	 Upper Half of PC
	*/
	private var PCH: UInt8

	/**
	 Stack Pointer
	*/
	private var SP: UInt8

	/**
	 Processor Status
	*/
	private var P: UInt8

	/**
	 Accumulator
	*/
	private var A: UInt8

	/**
	 Index Register X
	*/
	private var X: UInt8

	/**
	 Index Register Y
	*/
	private var Y: UInt8
	
	
	private var interruptDelay = false
	private var potentialCLILatencyDelay = false
	private var cliLatencyDelay = false

	private let mainMemory: CPUMemory
    private let ppu: PPU
	private let apu: APU
	
	private let logger: Logger
	
	/**
	 True if the last cycle run by the CPU was even
	*/
	private var evenCycle = false
	
	/**
	 True if page was crossed by last instruction
	*/
	private var pageCrossed = false
	
	private var dummyReadRequired = false
	private var dummyReadAddress: UInt16 = 0
	
	/**
	 True if CPU is currently running an OAM transfer
	*/
	private var oamTransfer = false
	
	private var oamDMAAddress: UInt16 = 0
	
	/**
	 Stores the number of cycles in the current OAM transfer
	*/
	private var oamCycles = 0
	
	/**
	 Stores whether OAM transfer will have an extra cycle
	*/
	private var oamExtraCycle = false
	
	/**
	 True if CPU is currently running a DMC transfer
	*/
	private var dmcTransfer = false
	
	/**
	 True if an error occurred
	*/
	var errorOccured = false
	
    enum AddressingMode {
        case accumulator
        
        case implied
        
        case immediate
        
        case absolute
        case absoluteIndexedX
        case absoluteIndexedY
        
        /**
         For JMP only
         */
        case absoluteIndirect
        
        case zeroPage
        case zeroPageIndexedX
        case zeroPageIndexedY
        
        case indirectX
        case indirectY
        
        case relative
    }
	
	var interruptWaiting: Bool
	var nmiTriggered: Bool {
		didSet {
			interruptWaiting = nmiTriggered || irqTriggered
		}
	}
	
	var irqTriggered: Bool {
		didSet {
			interruptWaiting = irqTriggered || irqTriggered
		}
	}
	var brkSetIRQ: Bool
	
	/**
	 Stores whether an interrupt occured on the previous cycle (when the NES polls the interrupt lines)
	*/
	var previousInterruptWaiting: Bool {
		didSet {
			if !previousInterruptWaiting {
				interruptDelay = false
			}
		}
	}
	var previousNMITriggered: Bool
	var previousIRQTriggered: Bool
	var previousBRKSetIRQ: Bool

	/**
	 Initializes the CPU
	*/
	init(mainMemory: CPUMemory, ppu: PPU, apu: APU, logger: Logger) {
		PCL = 0
		PCH = 0

		SP = 0

		P = 0x24

		A = 0
		X = 0
		Y = 0
		
		interruptWaiting = false
		nmiTriggered = false
		irqTriggered = false
		brkSetIRQ = false
		
		previousInterruptWaiting = false
		previousNMITriggered = false
		previousIRQTriggered = false
		previousBRKSetIRQ = false
		
		self.mainMemory = mainMemory
        self.ppu = ppu
		self.apu = apu
		self.logger = logger
    }
    
    func reset() {
        // Load program start address from RESET vector (0xFFFC)
        let programStartAddress = mainMemory.readTwoBytesMemory(0xFFFC)
		
		SP = 0xFD
		
		// Set interrupt flag
		setPBit(2, value: true)
		
		// Set unused flag
		setPBit(5, value: true)
        
        // Set PC to program start address
        setPC(programStartAddress)
        
        print("PC initialized to \((UInt16(self.PCH) << 8) | UInt16(self.PCL))")
    }
	
	/**
	 Executes one CPU instruction
	
	 - Returns: True if the instruction completed successfully, false otherwise
	*/
	func step() -> Bool {
		pageCrossed = false
		dummyReadRequired = false
		
		if oamTransfer {
			ppuStep()
			
			if oamExtraCycle {
				ppuStep()
			}
			
			let startAddress = UInt16(ppu.OAMADDR)
			
			for i: UInt16 in 0 ..< 256 {
				let data = readCycle(oamDMAAddress + i)
				
				ppuStep()
				
				ppu.writeDMA((startAddress + i) & 0xFF, data: data)
			}
			
			oamTransfer = false
			
			return true
		} else if dmcTransfer {
			for _ in 0 ..< 4 {
				ppuStep()
			}
			
			dmcTransfer = false
			return true
		}
		
		if previousInterruptWaiting {
			if interruptDelay && !(previousIRQTriggered && getPBit(2)) {
				interruptDelay = false
				potentialCLILatencyDelay = true
				cliLatencyDelay = true
			} else if previousNMITriggered {
				handleInterrupt()
				potentialCLILatencyDelay = false
				
				return true
			} else if previousIRQTriggered {
				if !getPBit(2) || previousBRKSetIRQ || cliLatencyDelay {
					handleInterrupt()
					cliLatencyDelay = false
					potentialCLILatencyDelay = false
					
					return true
				}
			} else {
				print("Error")
				
				return false
			}
		} else {
			cliLatencyDelay = false
			interruptDelay = false
			potentialCLILatencyDelay = false
		}
		
//		let cycle = self.ppu.getCycle()
//		let scanline = self.ppu.getScanline()
		
		ppuStep()
		let opcode = fetchPC()
		
//		self.logger.logFormattedInstuction(self.getPC() - 1, opcode: opcode, A: self.A, X: self.X, Y: self.Y, P: self.P, SP: self.SP, CYC: cycle, SL: scanline)
		
		switch opcode {
			// LDA
			case 0xA5:
				 LDA(.zeroPage)
			case 0xA9:
				 LDA(.immediate)
			case 0xB5:
				 LDA(.zeroPageIndexedX)
			case 0xAD:
				 LDA(.absolute)
			case 0xBD:
				 LDA(.absoluteIndexedX)
			case 0xB9:
				 LDA(.absoluteIndexedY)
			case 0xA1:
				 LDA(.indirectX)
			case 0xB1:
				 LDA(.indirectY)
			
			// BNE
			case 0xD0:
				 BNE()
			
			// JMP
			case 0x4C:
				 JMP(.absolute)
			case 0x6C:
				 JMP(.absoluteIndirect)
			
			// INX
			case 0xE8:
				 INX()
			
			// BPL
			case 0x10:
				 BPL()
			
			// CMP
			case 0xC9:
				 CMP(.immediate)
			case 0xC5:
				 CMP(.zeroPage)
			case 0xD5:
				 CMP(.zeroPageIndexedX)
			case 0xCD:
				 CMP(.absolute)
			case 0xDD:
				 CMP(.absoluteIndexedX)
			case 0xD9:
				 CMP(.absoluteIndexedY)
			case 0xC1:
				 CMP(.indirectX)
			case 0xD1:
				 CMP(.indirectY)
			
			// BMI
			case 0x30:
				 BMI()
			
			// BEQ
			case 0xF0:
				 BEQ()
			
			// BIT
			case 0x24:
				 BIT(.zeroPage)
			case 0x2C:
				 BIT(.absolute)
			
			// STA
			case 0x85:
				 STA(.zeroPage)
			case 0x95:
				 STA(.zeroPageIndexedX)
			case 0x8D:
				 STA(.absolute)
			case 0x9D:
				 STA(.absoluteIndexedX)
			case 0x99:
				 STA(.absoluteIndexedY)
			case 0x81:
				 STA(.indirectX)
			case 0x91:
				 STA(.indirectY)
			
			// DEX
			case 0xCA:
				 DEX()
			
			// INY
			case 0xC8:
				 INY()
			
			// TAY
			case 0xA8:
				 TAY()
			
			// INC
			case 0xE6:
				 INC(.zeroPage)
			case 0xF6:
				 INC(.zeroPageIndexedX)
			case 0xEE:
				 INC(.absolute)
			case 0xFE:
				 INC(.absoluteIndexedX)
			
			// BCS
			case 0xB0:
				 BCS()
			
			// JSR
			case 0x20:
				 JSR()
			
			// LSR
			case 0x4A:
				 LSR(.accumulator, dummyRead: true)
			case 0x46:
				 LSR(.zeroPage, dummyRead: true)
			case 0x56:
				 LSR(.zeroPageIndexedX, dummyRead: true)
			case 0x4E:
				 LSR(.absolute, dummyRead: true)
			case 0x5E:
				 LSR(.absoluteIndexedX, dummyRead: true)
			
			// RTS
			case 0x60:
				 RTS()
			
			// CLC
			case 0x18:
				 CLC()
			
			// AND
			case 0x29:
				 AND(.immediate)
			case 0x25:
				 AND(.zeroPage)
			case 0x35:
				 AND(.zeroPageIndexedX)
			case 0x2D:
				 AND(.absolute)
			case 0x3D:
				 AND(.absoluteIndexedX)
			case 0x39:
				 AND(.absoluteIndexedY)
			case 0x21:
				 AND(.indirectX)
			case 0x31:
				 AND(.indirectY)
			
			// ADC
			case 0x69:
				 ADC(.immediate)
			case 0x65:
				 ADC(.zeroPage)
			case 0x75:
				 ADC(.zeroPageIndexedX)
			case 0x6D:
				 ADC(.absolute)
			case 0x7D:
				 ADC(.absoluteIndexedX)
			case 0x79:
				 ADC(.absoluteIndexedY)
			case 0x61:
				 ADC(.indirectX)
			case 0x71:
				 ADC(.indirectY)
			
			// ALR
			case 0x4B:
				 ALR()
			
			// ANC
			case 0x0B, 0x2B:
				 ANC()
			
			// ASL
			case 0x0A:
				 ASL(.accumulator)
			case 0x06:
				 ASL(.zeroPage)
			case 0x16:
				 ASL(.zeroPageIndexedX)
			case 0x0E:
				 ASL(.absolute)
			case 0x1E:
				 ASL(.absoluteIndexedX)
			
			// ARR
			case 0x6B:
				 ARR()
			
			// AXS
			case 0xCB:
				 AXS()
			
			// BCC
			case 0x90:
				 BCC()
				
			// BRK
			case 0x00:
				 BRK()
				
			// BVC
			case 0x50:
				 BVC()
				
			// BVS
			case 0x70:
				 BVS()
				
			// CLD
			case 0xD8:
				 CLD()
				
			// CLI
			case 0x58:
				 CLI()
				
			// CLV
			case 0xB8:
				 CLV()
				
			// CPX
			case 0xE0:
				 CPX(.immediate)
			case 0xE4:
				 CPX(.zeroPage)
			case 0xEC:
				 CPX(.absolute)
				
			// CPY
			case 0xC0:
				 CPY(.immediate)
			case 0xC4:
				 CPY(.zeroPage)
			case 0xCC:
				 CPY(.absolute)
			
			// DCP
			case 0xCF:
				 DCP(.absolute)
			case 0xDB:
				 DCP(.absoluteIndexedY)
			case 0xDF:
				 DCP(.absoluteIndexedX)
			case 0xC7:
				 DCP(.zeroPage)
			case 0xD7:
				 DCP(.zeroPageIndexedX)
			case 0xC3:
				 DCP(.indirectX)
			case 0xD3:
				 DCP(.indirectY)
			
			// DEC
			case 0xC6:
				 DEC(.zeroPage)
			case 0xD6:
				 DEC(.zeroPageIndexedX)
			case 0xCE:
				 DEC(.absolute)
			case 0xDE:
				 DEC(.absoluteIndexedX)
				
			// DEY
			case 0x88:
				 DEY()
				
			// EOR
			case 0x49:
				 EOR(.immediate)
			case 0x45:
				 EOR(.zeroPage)
			case 0x55:
				 EOR(.zeroPageIndexedX)
			case 0x4D:
				 EOR(.absolute)
			case 0x5D:
				 EOR(.absoluteIndexedX)
			case 0x59:
				 EOR(.absoluteIndexedY)
			case 0x41:
				 EOR(.indirectX)
			case 0x51:
				 EOR(.indirectY)
			
			// IGN
			case 0x0C:
				 IGN(.absolute)
			case 0x1C, 0x3C, 0x5C, 0x7C, 0xDC, 0xFC:
				 IGN(.absoluteIndexedX)
			case 0x04, 0x44, 0x64:
				 IGN(.zeroPage)
			case 0x14, 0x34, 0x54, 0x74, 0xD4, 0xF4:
				 IGN(.zeroPageIndexedX)
			
			// ISC
			case 0xEF:
				 ISC(.absolute)
			case 0xFF:
				 ISC(.absoluteIndexedX)
			case 0xFB:
				 ISC(.absoluteIndexedY)
			case 0xE7:
				 ISC(.zeroPage)
			case 0xF7:
				 ISC(.zeroPageIndexedX)
			case 0xE3:
				 ISC(.indirectX)
			case 0xF3:
				 ISC(.indirectY)
			
			// LAX
			case 0xA7:
				 LAX(.zeroPage)
			case 0xB7:
				 LAX(.zeroPageIndexedY)
			case 0xAF:
				 LAX(.absolute)
			case 0xBF:
				 LAX(.absoluteIndexedY)
			case 0xA3:
				 LAX(.indirectX)
			case 0xB3:
				 LAX(.indirectY)
			
			// LDX
			case 0xA2:
				 LDX(.immediate)
			case 0xA6:
				 LDX(.zeroPage)
			case 0xB6:
				 LDX(.zeroPageIndexedY)
			case 0xAE:
				 LDX(.absolute)
			case 0xBE:
				 LDX(.absoluteIndexedY)
				
			// LDY
			case 0xA0:
				 LDY(.immediate)
			case 0xA4:
				 LDY(.zeroPage)
			case 0xB4:
				 LDY(.zeroPageIndexedX)
			case 0xAC:
				 LDY(.absolute)
			case 0xBC:
				 LDY(.absoluteIndexedX)
			
			// LXA
			// Assuming XAA (0x8B) is the same as LXA
			case 0x8B, 0xAB:
				 LXA()
				
			// NOP
			case 0xEA, 0x1A, 0x3A, 0x5A, 0x7A, 0xDA, 0xFA:
				 NOP()
				
			// ORA
			case 0x09:
				 ORA(.immediate)
			case 0x05:
				 ORA(.zeroPage)
			case 0x15:
				 ORA(.zeroPageIndexedX)
			case 0x0D:
				 ORA(.absolute)
			case 0x1D:
				 ORA(.absoluteIndexedX)
			case 0x19:
				 ORA(.absoluteIndexedY)
			case 0x01:
				 ORA(.indirectX)
			case 0x11:
				 ORA(.indirectY)
				
			// PHA
			case 0x48:
				 PHA()
				
			// PHP
			case 0x08:
				 PHP()
				
			// PLA
			case 0x68:
				 PLA()
				
			// PLP
			case 0x28:
				 PLP()
			
			// RLA
			case 0x2F:
				 RLA(.absolute)
			case 0x3F:
				 RLA(.absoluteIndexedX)
			case 0x3B:
				 RLA(.absoluteIndexedY)
			case 0x27:
				 RLA(.zeroPage)
			case 0x37:
				 RLA(.zeroPageIndexedX)
			case 0x23:
				 RLA(.indirectX)
			case 0x33:
				 RLA(.indirectY)
			
			// ROL
			case 0x2A:
				 ROL(.accumulator)
			case 0x26:
				 ROL(.zeroPage)
			case 0x36:
				 ROL(.zeroPageIndexedX)
			case 0x2E:
				 ROL(.absolute)
			case 0x3E:
				 ROL(.absoluteIndexedX)
				
			// ROR
			case 0x6A:
				 ROR(.accumulator, dummyRead: true)
			case 0x66:
				 ROR(.zeroPage, dummyRead: true)
			case 0x76:
				 ROR(.zeroPageIndexedX, dummyRead: true)
			case 0x6E:
				 ROR(.absolute, dummyRead: true)
			case 0x7E:
				 ROR(.absoluteIndexedX, dummyRead: true)
            
            // RRA
            case 0x6F:
                 RRA(.absolute)
            case 0x7F:
                 RRA(.absoluteIndexedX)
            case 0x7B:
                 RRA(.absoluteIndexedY)
            case 0x67:
                 RRA(.zeroPage)
            case 0x77:
                 RRA(.zeroPageIndexedX)
            case 0x63:
                 RRA(.indirectX)
            case 0x73:
                 RRA(.indirectY)
				
			// RTI
			case 0x40:
				 RTI()
			
			// SAX
			case 0x8F:
				 SAX(.absolute)
			case 0x87:
				 SAX(.zeroPage)
			case 0x83:
				 SAX(.indirectX)
			case 0x97:
				 SAX(.zeroPageIndexedY)
			
			// SBC
			case 0xE9, 0xEB:
				 SBC(.immediate)
			case 0xE5:
				 SBC(.zeroPage)
			case 0xF5:
				 SBC(.zeroPageIndexedX)
			case 0xED:
				 SBC(.absolute)
			case 0xFD:
				 SBC(.absoluteIndexedX)
			case 0xF9:
				 SBC(.absoluteIndexedY)
			case 0xE1:
				 SBC(.indirectX)
			case 0xF1:
				 SBC(.indirectY)
				
			// SEC
			case 0x38:
				 SEC()
				
			// SED
			case 0xF8:
				 SED()
				
			// SEI
			case 0x78:
				 SEI()
			
			// SKB
			case 0x80, 0x82, 0x89, 0xC2, 0xE2:
				 SKB()
			
			// SLO
			case 0x0F:
				 SLO(.absolute)
			case 0x1F:
				 SLO(.absoluteIndexedX)
			case 0x1B:
				 SLO(.absoluteIndexedY)
			case 0x07:
				 SLO(.zeroPage)
			case 0x17:
				 SLO(.zeroPageIndexedX)
			case 0x03:
				 SLO(.indirectX)
			case 0x13:
				 SLO(.indirectY)
			
			// SRE
			case 0x4F:
				 SRE(.absolute)
			case 0x5F:
				 SRE(.absoluteIndexedX)
			case 0x5B:
				 SRE(.absoluteIndexedY)
			case 0x47:
				 SRE(.zeroPage)
			case 0x57:
				 SRE(.zeroPageIndexedX)
			case 0x43:
				 SRE(.indirectX)
			case 0x53:
				 SRE(.indirectY)
				
			// STX
			case 0x86:
				 STX(.zeroPage)
			case 0x96:
				 STX(.zeroPageIndexedY)
			case 0x8E:
				 STX(.absolute)
				
			// STY
			case 0x84:
				 STY(.zeroPage)
			case 0x94:
				 STY(.zeroPageIndexedX)
			case 0x8C:
				 STY(.absolute)
			
			// SXA
			case 0x9E:
				 SXA()
			
			// SYA
			case 0x9C:
				 SYA()
			
			// TAX
			case 0xAA:
				 TAX()
				
			// TSX
			case 0xBA:
				 TSX()
				
			// TXA
			case 0x8A:
				 TXA()
				
			// TXS
			case 0x9A:
				 TXS()
				
			// TYA
			case 0x98:
				 TYA()
			
			// TAS
			case 0x9B:
				TAS()
			
			// AXA
			case 0x9F:
				AXA(.absoluteIndexedY)
			case 0x93:
				AXA(.indirectY)
			
			// LAS
			case 0xBB:
				LAS()
			
			default:
				print("ERROR: Instruction with opcode 0x\(logger.hexString(opcode, padding: 2)) not found")
				self.errorOccured = true
				return false
		}
		
		return true
	}
	
	func readCycle(_ address: UInt16) -> UInt8 {
		ppuStep()
		
		return mainMemory.readMemory(address)
	}
	
	func writeCycle(_ address: UInt16, data: UInt8) {
		ppuStep()
		
		mainMemory.writeMemory(address, data: data)
	}
	
	func ppuStep() {
		evenCycle = !evenCycle
		
		apu.step()
		
		for _ in 0 ..< 3 {
			ppu.step()
		}
		
		previousInterruptWaiting = interruptWaiting
		previousIRQTriggered = irqTriggered
		previousNMITriggered = nmiTriggered
		previousBRKSetIRQ = brkSetIRQ
	}
	
    func address(_ lower: UInt8, upper: UInt8) -> UInt16 {
        return UInt16(lower) | (UInt16(upper) << 8)
    }
    
    func setPBit(_ index: Int, value: Bool) {
        let bit: UInt8 = value ? 0xFF : 0
        P ^= (bit ^ P) & (1 << UInt8(index))
    }
    
    func getPBit(_ index: Int) -> Bool {
        return ((P >> UInt8(index)) & 0x1) == 1
    }
    
    func readFromMemoryUsingAddressingMode(_ mode: AddressingMode) -> UInt8 {
        switch mode {
			case .immediate:
				ppuStep()
				return fetchPC()
			default: break
        }
        
        return readCycle(addressUsingAddressingMode(mode))
    }
    
    func addressUsingAddressingMode(_ mode: AddressingMode) -> UInt16 {
        switch mode {
			case AddressingMode.zeroPage:
				ppuStep()
				return UInt16(fetchPC())
			case AddressingMode.zeroPageIndexedX, .zeroPageIndexedY:
				var index = X
				
				if(mode == AddressingMode.zeroPageIndexedY) {
					index = Y
				}
				
				ppuStep()
				let pc = fetchPC()
				
				ppuStep()
				
				return UInt16(pc &+ index)
			case AddressingMode.absolute:
				ppuStep()
				let lowByte = fetchPC()
				ppuStep()
				let highByte = fetchPC()
				
				return address(lowByte, upper: highByte)
			case AddressingMode.absoluteIndexedX, .absoluteIndexedY:
				ppuStep()
				let lowByte = fetchPC()
				
				ppuStep()
				let highByte = fetchPC()
				
				var index = X
				
				if(mode == AddressingMode.absoluteIndexedY) {
					index = Y
				}

				let index16 = UInt16(index)
				
				let originalAddress = address(lowByte, upper: highByte)
				
				if UInt16(lowByte) + index16 > 0xFF {
					dummyReadRequired = true
				}
				
				dummyReadAddress = ((originalAddress & 0xFF00) | (originalAddress &+ index16) & 0xFF)
				
				let newAddress = (originalAddress &+ index16)
				
				pageCrossed = !checkPage(UInt16(newAddress), originalAddress: UInt16(originalAddress))
				
				return newAddress
			case AddressingMode.indirectX:
				ppuStep()
				let immediate = fetchPC()
				
				ppuStep()
				
				let lowByte = readCycle(UInt16(immediate &+ X))
				
				let highByte = readCycle(UInt16(immediate &+ X &+ 1))
				
				return address(lowByte, upper: highByte)
			case AddressingMode.indirectY:
				ppuStep()
				let immediate = UInt16(fetchPC())
				
				let lowByte = readCycle(immediate)
				let highByte = readCycle((immediate + 1) & 0xFF)
				
				let originalAddress = address(lowByte, upper: highByte)
				
				if(UInt16(lowByte) + UInt16(Y) > 0xFF) {
					dummyReadRequired = true
				}
				
				let y16 = UInt16(Y)
				
				dummyReadAddress = ((originalAddress & 0xFF00) | (originalAddress + y16) & 0xFF)
				
				let newAddress = originalAddress &+ y16
				
				pageCrossed = !checkPage(newAddress, originalAddress: originalAddress)
				
				return newAddress
			default:
				print("Invalid AddressingMode on addressUsingAddressingMode")
				return 0
        }
    }
	
	/**
	 Returns true if the address lies on the same page as PC
	*/
	func checkPage(_ address: UInt16) -> Bool {
		return checkPage(address, originalAddress: getPC())
	}
	
	/**
	 Returns true if the address lies on the same page as originalAddress
	*/
	func checkPage(_ address: UInt16, originalAddress: UInt16) -> Bool {
		return address / 0x100 == originalAddress / 0x100
	}
	
	/**
	 Converts the given value to binary coded decimal, where
	 the first nibble is a tens place digit, and the second a
	 ones place digit
	*/
	func bcdValue(_ value: UInt8) -> UInt8 {
		let upper = (value >> 4) & 0xF
		let lower = value & 0xF
		
		return upper * 10 + lower
	}
	
	/**
	 Sets a interrupt to trigger upon the next clock cycle
	*/
//	func queueInterrupt(interrupt: Interrupt?) {
//		self.interrupt = interrupt
//		self.interruptDelay = false
//	}
	func queueIRQ() {
		irqTriggered = true
	}
	
	func clearIRQ() {
		irqTriggered = false
	}
	
	func queueNMI() {
		nmiTriggered = true
	}
	
	func clearNMI() {
		nmiTriggered = false
	}
	
	/**
	 Handles the current interrupt
	*/
	func handleInterrupt() {
		let brk = previousBRKSetIRQ
		
		if(!brk) {
			ppuStep()
		}
		
		// Dummy read
		_ = readCycle(getPC())
		
		if brk {
			incrementPC()
		}
		
		let oldPCL = PCL
		let oldPCH = PCH
		
		// When performing a hardware interrupt, do not set the B flag
		var pMask: UInt8 = 0x20
		
		if(brk) {
			pMask = 0x30
		}
		
		push(oldPCH)
		push(oldPCL)
		
		push(P | pMask)
		
		// Set interrupt flag
		setPBit(2, value: true)
		
		var PCLAddr: UInt16 = 0
		var PCHAddr: UInt16 = 0
		
		if previousNMITriggered {
			PCLAddr = 0xFFFA
			PCHAddr = 0xFFFB
			
			self.brkSetIRQ = false
			self.irqTriggered = false
			self.nmiTriggered = false
		} else if previousIRQTriggered {
			PCLAddr = 0xFFFE
			PCHAddr = 0xFFFF
			
			if brkSetIRQ {
				irqTriggered = false
				brkSetIRQ = false
			}
		} else {
			// TODO: Handle reset case?
		}
		
		PCL = readCycle(PCLAddr)
		PCH = readCycle(PCHAddr)
	}
	
	func startOAMTransfer() {
		oamTransfer = true
		oamCycles = 0

		oamExtraCycle = !evenCycle

		oamDMAAddress = (UInt16(ppu.OAMDMA) << 8) & 0xFF00
	}
	
	func startDMCTransfer() {
		dmcTransfer = true
	}
	
    // MARK: - PC Operations
    func setPC(_ address: UInt16) {
        PCL = UInt8(address & 0xFF)
        PCH = UInt8((address & 0xFF00) >> 8)
    }
    
    func getPC() -> UInt16 {
        return UInt16(PCL) | (UInt16(PCH) << 8)
    }
    
    func incrementPC() {
        setPC(getPC() &+ 1)
    }
    
    func decrementPC() {
		setPC(getPC() &- 1)
    }
    
    func fetchPC() -> UInt8 {
        let byte = mainMemory.readMemory(getPC())
        
        incrementPC()
        
        return byte
    }
    
    // MARK: - Stack Operations
    func push(_ byte: UInt8) {
        writeCycle(0x100 + UInt16(SP), data: byte)
        
        SP = SP &- 1
    }
    
    func pop() -> UInt8 {
		SP = SP &+ 1
		
        return readCycle(0x100 + UInt16(SP))
    }
    
    // MARK: - Instructions
    // MARK: Stack
    
    /**
     Simulate Interrupt ReQuest (IRQ)
    */
    func BRK() {
		queueIRQ()
		
		brkSetIRQ = true
		previousBRKSetIRQ = true
		
		previousInterruptWaiting = true
		previousIRQTriggered = true
    }
    
    /**
     ReTurn from Interrupt
    */
    func RTI() {
		// Dummy read
		_ = readCycle(getPC())
		
        P = pop()
        PCL = pop()
        PCH = pop()
		
		ppuStep()
		
		// Force B flag to be clear
		setPBit(4, value: false)
		
		// Force unused flag to be set
		setPBit(5, value: true)
		
		if potentialCLILatencyDelay {
			potentialCLILatencyDelay = false
			cliLatencyDelay = false
		}
    }
    
    /**
     ReTurn from Subroutine
    */
    func RTS() {
		// Dummy read
		_ = readCycle(getPC())
		
        PCL = pop()
        PCH = pop()
		
		ppuStep()
        
        incrementPC()
		
		ppuStep()
    }
    
    /**
     PusH A
    */
    func PHA() {
		// Dummy read
		_ = readCycle(getPC())
		
		push(A)
    }
    
    /**
     PusH P
    */
    func PHP() {
		// Dummy read
		_ = readCycle(getPC())
		
		// Force break flag to be set
		setPBit(4, value: true)
		
        push(P)
		
		setPBit(4, value: false)
    }
    
    /**
     PulL from Stack to A
    */
    func PLA() {
		// Dummy read
		_ = readCycle(getPC())
		
		ppuStep()
		
		A = pop()
		
		// Set negative flag
		setPBit(7, value: (A >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (A == 0))
    }
    
    /**
     PulL from Stack to P
    */
    func PLP() {
		// Dummy read
		_ = readCycle(getPC())
		
		ppuStep()
		
		P = pop()
		
		// Ensure break flag is not set
		setPBit(4, value: false)
		
		// Ensure unused bit is set
		setPBit(5, value: true)
		if !potentialCLILatencyDelay {
			interruptDelay = true
		}
    }
    
    /**
     Jump to SubRoutine
    */
    func JSR() {
		ppuStep()
		let lowByte = fetchPC()
		
		ppuStep()
		
		let temp = getPC()
        
        push(UInt8((temp >> 8) & 0xFF))
        push(UInt8(temp & 0xFF))
		
		ppuStep()
        PCH = fetchPC()
        PCL = lowByte
    }
	
	// MARK: Memory
	
	/**
	 Store A in Memory
	*/
	func STA(_ mode: AddressingMode) {
		let address = addressUsingAddressingMode(mode)
		
		// Ignore page cross
		
		if(mode == .absoluteIndexedX || mode == .absoluteIndexedY || mode == .indirectY) {
			let _ = readCycle(dummyReadAddress)
		}
		
		writeCycle(address, data: A)
	}
	
	/**
	 Store X in Memory
	*/
	func STX(_ mode: AddressingMode) {
		let address = addressUsingAddressingMode(mode)
		
		// Ignore page cross
		writeCycle(address, data: X)
	}
	
	/**
	 Store Y in Memory
	*/
	func STY(_ mode: AddressingMode) {
		let address = addressUsingAddressingMode(mode)
		
		// Ignore page cross
		writeCycle(address, data: Y)
	}
	
	/**
	 Store A AND X in Memory (unofficial)
	*/
	func SAX(_ mode: AddressingMode) {
		let address = addressUsingAddressingMode(mode)
		
		// Ignore page cross
		
		if(mode == .absoluteIndexedX || mode == .absoluteIndexedY || mode == .indirectY) {
			let _ = readCycle(address)
		}
		
		writeCycle(address, data: A & X)
	}
	
	/**
	 Load A from Memory
	*/
	func LDA(_ mode: AddressingMode) {
		LOAD(mode, register: &A)
	}
	
	/**
	 Load X from Memory
	*/
	func LDX(_ mode: AddressingMode) {
		LOAD(mode, register: &X)
	}
	
	/**
	 Load Y from Memory
	*/
	func LDY(_ mode: AddressingMode) {
		LOAD(mode, register: &Y)
	}
	
	/**
	 Load A and X from Memory (unofficial)
	*/
	func LAX(_ mode: AddressingMode) {
		LOAD(mode, register: &A)
		X = A
	}
	
	/**
	Internal handler for LDA, LDX, LDY
	*/
	func LOAD(_ mode: AddressingMode, register: UnsafeMutablePointer<UInt8>) {
		if mode == .immediate {
			ppuStep()
			register.pointee = fetchPC()
		} else {
			let address = addressUsingAddressingMode(mode)
			
			if pageCrossed {
				if dummyReadRequired {
					_ = readCycle(dummyReadAddress)
				} else {
					_ = readCycle(address)
				}
			}
			
			register.pointee = readCycle(address)
		}
		
		// Set negative flag
		setPBit(7, value: (register.pointee >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (register.pointee == 0))
	}
	
	/**
	 Transfer A to X
	*/
	func TAX() {
		// Dummy read
		_ = readCycle(getPC())
		
		X = A
		
		// Set negative flag
		setPBit(7, value: (X >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (X == 0))
	}
	
	/**
	 Transfer A to Y
	*/
	func TAY() {
		// Dummy read
		_ = readCycle(getPC())
		
		Y = A
		
		// Set negative flag
		setPBit(7, value: (Y >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (Y == 0))
	}
	
	/**
	 Transfer Stack Pointer to X
	*/
	func TSX() {
		// Dummy read
		_ = readCycle(getPC())
		
		X = SP
		
		// Set negative flag
		setPBit(7, value: (X >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (X == 0))
	}
	
	/**
	 Transfer X to A
	*/
	func TXA() {
		// Dummy read
		_ = readCycle(getPC())
		
		A = X
		
		// Set negative flag
		setPBit(7, value: (A >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (A == 0))
	}
	
	/**
	 Transfer X to SP
	*/
	func TXS() {
		// Dummy read
		_ = readCycle(getPC())
		
		SP = X
	}
	
	/**
	 Transfer Y to A
	*/
	func TYA() {
		// Dummy read
		_ = readCycle(getPC())
		
		A = Y
		
		// Set negative flag
		setPBit(7, value: (A >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (A == 0))
	}
	
	/**
	 Transfer A AND X into S and Store (Unofficial)
	*/
	func TAS() {
		SP = A & X
		
		ppuStep()
		
		let address = addressUsingAddressingMode(.absoluteIndexedY)
		
		writeCycle(address, data: SP & PCH)
	}
	
	/**
	 AND X with A AND 7 and store (Unofficial)
	*/
	func AXA(_ mode: AddressingMode) {
		let temp = A & X & 0x7
		
		ppuStep()
		
		let address = addressUsingAddressingMode(mode)
		
		writeCycle(address, data: temp)
	}
	
	/**
	 Load A, X, S from address AND S (Unofficial)
	*/
	func LAS() {
		let memory = readFromMemoryUsingAddressingMode(.absoluteIndexedY) & SP
		
		A = memory
		X = memory
		SP = memory
		
		if pageCrossed {
			ppuStep()
		}
	}
	
    /**
     JuMP
    */
    func JMP(_ mode: AddressingMode) {
        switch mode {
            case AddressingMode.absolute:
				ppuStep()
                let lowByte = fetchPC()
				
				ppuStep()
                PCH = fetchPC()
                PCL = lowByte
            case AddressingMode.absoluteIndirect:
				ppuStep()
				let lowerByte = UInt16(fetchPC())
				
				ppuStep()
				let higherByte = UInt16(fetchPC()) << 8
				
                PCL = readCycle(lowerByte | higherByte)
				// Add 1 only to lower byte due to CPU bug
                PCH = readCycle(((lowerByte &+ 1) & 0xFF) | higherByte)
            default:
                print("Invalid AddressingMode on JMP")
        }
    }
	
    // MARK: Math
    
    /**
     Add Memory to A with Carry
    */
    func ADC(_ mode: AddressingMode) {
		let memoryValue = readFromMemoryUsingAddressingMode(mode)
		
		let temp = UInt16(A) + UInt16(memoryValue) + (getPBit(0) ? 1 : 0)
		
		// Set overflow flag
		setPBit(6, value: (~(A ^ memoryValue) & (A ^ UInt8(temp & 0xFF)) & 0x80) == 0x80)
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1)
		
		// Set zero flag
		setPBit(1, value: (temp & 0xFF) == 0)
		
		// Decimal mode not supported by NES CPU
		// Decimal flag
		/*if(getPBit(3)) {
			temp = UInt16(bcdValue(self.A)) + UInt16(bcdValue(memoryValue)) + (getPBit(0) ? 1 : 0)
			
			// Set carry flag
			setPBit(0, value: temp > 99)
		} else {*/
		
		// Set carry flag
		setPBit(0, value: temp > 255)
		
		A = UInt8(temp & 0xFF)
		
		if pageCrossed {
			_ = readCycle(dummyReadAddress)
		}
    }
    
    /**
     Subtract Memory to A with Borrow
    */
    func SBC(_ mode: AddressingMode) {
		let memoryValue = readFromMemoryUsingAddressingMode(mode)
		
		var temp: Int
		
		// Decimal mode not supported by NES CPU
		// Decimal flag
		/*if(getPBit(3)) {
			temp = Int(bcdValue(self.A)) - Int(bcdValue(memoryValue)) - (getPBit(0) ? 0 : 1)
			
			// Set overflow flag
			setPBit(6, value: (temp > 99) || (temp < 0))
		} else {*/
		
		temp = Int(A) - Int(memoryValue) - (getPBit(0) ? 0 : 1)
		
		// Set overflow flag
		setPBit(6, value: ((A ^ memoryValue) & (A ^ UInt8(temp & 0xFF)) & 0x80) == 0x80)
		
		// Set carry flag
		setPBit(0, value: temp >= 0)
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1)
		
		// Set zero flag
		setPBit(1, value: (temp & 0xFF) == 0)
		
		A = UInt8(temp & 0xFF)
		
		if pageCrossed {
			_ = readCycle(dummyReadAddress)
		}
    }
	
	/**
	 Increment Memory
	*/
	func INC(_ mode: AddressingMode) {
		let address = addressUsingAddressingMode(mode)
		
		// Ignore page cross
		
		var value = Int(readCycle(address))
		
		ppuStep()
		
		value = value + 1
		
		// Set negative flag
		setPBit(7, value: (value >> 7) & 0x1 == 1)
		
		// Set zero flag
		setPBit(1, value: ((value & 0xFF) == 0))
		
		if mode == .absoluteIndexedX {
			_ = readCycle(dummyReadAddress)
		}
		
		writeCycle(address, data: UInt8(value & 0xFF))
	}
	
	/**
	 Increment X
	*/
	func INX() {
		ppuStep()
		
		X = X &+ 1
		
		// Set negative flag
		setPBit(7, value: (X >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (X == 0))
	}
	
	/**
	 Increment Y
	*/
	func INY() {
		ppuStep()
		
		Y = Y &+ 1
		
		// Set negative flag
		setPBit(7, value: (Y >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (Y == 0))
	}
	
	/**
	 Increment Memory then SBC (unofficial)
	*/
	func ISC(_ mode: AddressingMode) {
		let address = addressUsingAddressingMode(mode)
		var value = Int(readCycle(address))
		
		// Ignore page cross
		
		ppuStep()
		
		value = value + 1
		
		let temp = Int(A) - Int(value & 0xFF) - (getPBit(0) ? 0 : 1)
		
		// Set overflow flag
		setPBit(6, value: ((A ^ UInt8(value & 0x80)) & (A ^ UInt8(temp & 0xFF)) & 0x80) == 0x80)
		
		// Set carry flag
		setPBit(0, value: temp >= 0)
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1)
		
		// Set zero flag
		setPBit(1, value: (temp & 0xFF) == 0)
		
		A = UInt8(temp & 0xFF)
		
		if mode == .absoluteIndexedX || mode == .absoluteIndexedY || mode == .indirectY {
			_ = readCycle(address)
		}
		
		writeCycle(address, data: UInt8(value & 0xFF))
	}
	
	/**
	 Decrement Memory then CMP (unofficial)
	*/
	func DCP(_ mode: AddressingMode) {
		let address = addressUsingAddressingMode(mode)
		var value = Int(readCycle(address))
		
		// Ignore page cross
		
		ppuStep()
		
		value = value - 1
		
		let temp = Int(A) - value
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1)
		
		// Set zero flag
		setPBit(1, value: ((temp & 0xFF) == 0))
		
		// Set carry flag
		setPBit(0, value: (UInt8(A & 0xFF) >= UInt8(value & 0xFF)))
		
		if mode == .absoluteIndexedX || mode == .absoluteIndexedY || mode == .indirectY {
			let _ = readCycle(address)
		}
		
		writeCycle(address, data: UInt8(value & 0xFF))
	}
	
	/**
	 Decrement Memory
	*/
	func DEC(_ mode: AddressingMode) {
		let address = addressUsingAddressingMode(mode)
		
		// Ignore page cross
		
		var value = Int(readCycle(address))
		
		ppuStep()
		
		value = value - 1
		
		// Set negative flag
		setPBit(7, value: (value >> 7) & 0x1 == 1)
		
		// Set zero flag
		setPBit(1, value: ((value & 0xFF) == 0))
		
		if mode == .absoluteIndexedX {
			_ = readCycle(dummyReadAddress)
		}
		
		writeCycle(address, data: UInt8(value & 0xFF))
	}
	
	/**
	 Decrement X
	*/
	func DEX() {
		ppuStep()
		
		X = UInt8((Int(X) - 1) & 0xFF)
		
		// Set negative flag
		setPBit(7, value: (X >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (X == 0))
	}
	
	/**
	 Decrement Y
	*/
	func DEY() {
		ppuStep()
		
		Y = UInt8((Int(Y) - 1) & 0xFF)
		
		// Set negative flag
		setPBit(7, value: (Y >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (Y == 0))
	}
	
    /**
     Arithmetic Shift Left
    */
    func ASL(_ mode: AddressingMode) {
        if mode == .accumulator {
			// Dummy read
			let _ = readCycle(getPC())
			
			// Set carry flag
            setPBit(0, value: (A >> 7) == 1)
            
            A = (A << 1) & 0xFE
            
            // Set negative flag
            setPBit(7, value: (A >> 7) == 1)
            
            // Set zero flag
            setPBit(1, value: (A == 0))
        } else {
            let address = addressUsingAddressingMode(mode)
			
			// Ignore page cross
			
            let value = readCycle(address)
			
			ppuStep()
            
            // Set carry flag
            setPBit(0, value: (value >> 7) == 1)
            
            let temp = (value << 1) & 0xFE
            
            // Set negative flag
            setPBit(7, value: (temp >> 7) == 1)
            
            // Set zero flag
            setPBit(1, value: (temp == 0))
			
			if mode == .absoluteIndexedX {
				let _ = readCycle(dummyReadAddress)
			}
            
            writeCycle(address, data: temp)
        }
    }
	
	/**
	 Shift Left and ORA (unofficial)
	*/
	func SLO(_ mode: AddressingMode) {
		let address = addressUsingAddressingMode(mode)
		let value = readCycle(address)
		
		// Ignore page cross
		
		ppuStep()
		
		// Set carry flag
		setPBit(0, value: (value >> 7) == 1)
		
		let temp = (value << 1) & 0xFE
		
		A = A | temp
		
		// Set negative flag
		setPBit(7, value: (A >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (A == 0))
		
		if mode == .absoluteIndexedX || mode == .absoluteIndexedY || mode == .indirectY {
			_ = readCycle(address)
		}
		
		writeCycle(address, data: temp)
	}
	
    /**
     Logical Shift Right
    */
	func LSR(_ mode: AddressingMode, dummyRead: Bool) {
        if mode == .accumulator {
			// Dummy read
			if dummyRead {
				_ = readCycle(getPC())
			}
			
			// Set negative flag
            setPBit(7, value: false)
            
            // Set carry flag
            setPBit(0, value: (A & 0x1) == 1)
            
            A = (A >> 1) & 0x7F
            
            // Set zero flag
            setPBit(1, value: (A == 0))
        } else {
            let address = addressUsingAddressingMode(mode)
			
			// Ignore page cross
			
            let value = readCycle(address)
			
			ppuStep()
            
            // Set negative flag
            setPBit(7, value: false)
            
            // Set carry flag
            setPBit(0, value: (value & 0x1) == 1)
            
            let temp = (value >> 1) & 0x7F
            
            // Set zero flag
            setPBit(1, value: (temp == 0))
			
			if mode == .absoluteIndexedX {
				_ = readCycle(dummyReadAddress)
			}
            
            writeCycle(address, data: temp)
        }
    }
	
	/**
	 Logical Shift Right and EOR (unofficial)
	*/
	func SRE(_ mode: AddressingMode) {
		let address = addressUsingAddressingMode(mode)
		let value = readCycle(address)
		
		ppuStep()
		
		// Ignore page cross
		
		// Set carry flag
		setPBit(0, value: (value & 0x1) == 1)
		
        // TODO: Possibly incorrect (seems to pass tests though)
		let temp = (value >> 1) & 0x7F
		
		A = A ^ temp
		
		// Set negative flag
		setPBit(7, value: (A >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (A == 0))
		
		if mode == .absoluteIndexedX || mode == .absoluteIndexedY || mode == .indirectY {
			_ = readCycle(address)
		}
		
		writeCycle(address, data: temp)
	}
	
    /**
     ROtate Left
    */
    func ROL(_ mode: AddressingMode) {
        if mode == .accumulator {
			// Dummy read
			_ = readCycle(getPC())
			
			let carry = (A >> 7) & 0x1
            
            A = (A << 1) & 0xFE
            A = A | (getPBit(0) ? 1:0)
			
			// Set carry flag
			setPBit(0, value: carry == 1)
			
			// Set zero flag
			setPBit(1, value: (A == 0))
			
            // Set negative flag
            setPBit(7, value: (A >> 7) & 0x1 == 1)
        } else {
            let address = addressUsingAddressingMode(mode)
			
			if mode == .absoluteIndexedX {
				_ = readCycle(dummyReadAddress)
			}
			
			var value = readCycle(address)
			
			// Ignore page cross
			
			ppuStep()
			
			let carry = (value >> 7) & 0x1
			value = (value << 1) & 0xFE
			value = value | (getPBit(0) ? 1:0)
            
			// Set carry flag
			setPBit(0, value: carry == 1)
			
			// Set zero flag
			setPBit(1, value: (value == 0))
			
			// Set negative flag
			setPBit(7, value: (value >> 7) & 0x1 == 1)
			
            writeCycle(address, data: value)
        }
    }
	
	/**
	 ROtate Right
	*/
	func ROR(_ mode: AddressingMode, dummyRead: Bool) {
		if mode == .accumulator {
			// Dummy read
			if dummyRead {
				_ = readCycle(getPC())
			}
			
			let carry = A & 0x1
			
			A = (A >> 1) & 0x7F
			A = A | (getPBit(0) ? 0x80 : 0)
			
			// Set carry flag
			setPBit(0, value: carry == 1)
			
			// Set zero flag
			setPBit(1, value: (A == 0))
			
			// Set negative flag
			setPBit(7, value: (A >> 7) & 0x1 == 1)
		} else {
			let address = addressUsingAddressingMode(mode)
			
			var value = readCycle(address)
			
			if mode == .absoluteIndexedX {
				_ = readCycle(dummyReadAddress)
			}
			
			// Ignore page cross
			
			ppuStep()
			
			let carry = value & 0x1
			value = (value >> 1) & 0x7F
			value = value | (getPBit(0) ? 0x80 : 0)
			
			// Set carry flag
			setPBit(0, value: carry == 1)
			
			// Set zero flag
			setPBit(1, value: (value == 0))
			
			// Set negative flag
			setPBit(7, value: (value >> 7) & 0x1 == 1)
			
			writeCycle(address, data: value)
		}
	}
	
	/**
	 ROtate Left and AND (unofficial)
	*/
	func RLA(_ mode: AddressingMode) {
		let address = addressUsingAddressingMode(mode)
		var value = readCycle(address)
		
		// Ignore page cross
		
		if mode == .absoluteIndexedX || mode == .absoluteIndexedY || mode == .indirectY {
			_ = readCycle(dummyReadAddress)
		}
		
		ppuStep()
		
		let carry = (value >> 7) & 0x1
		value = (value << 1) & 0xFE
		value = value | (getPBit(0) ? 1:0)
		
		// Set carry flag
		setPBit(0, value: carry == 1)
		
		A = A & value
		
		// Set negative flag
		setPBit(7, value: (A >> 7) == 1)
		
		// Set zero flag
		setPBit(1, value: (A == 0))
		
		writeCycle(address, data: value)
	}
    
    /**
     ROtate Right and Add (unofficial)
    */
    func RRA(_ mode: AddressingMode) {
        let address = addressUsingAddressingMode(mode)
        var value = readCycle(address)
		
		// Ignore page cross
		
		if mode == .absoluteIndexedX || mode == .absoluteIndexedY || mode == .indirectY {
			let _ = readCycle(dummyReadAddress)
		}
		
		ppuStep()
        
        let carry = value & 0x1
        value = (value >> 1) & 0x7F
        value = value | (getPBit(0) ? 0x80 : 0)
        
        let temp = UInt16(A) + UInt16(value) + UInt16(carry)
        
        // Set overflow flag
        setPBit(6, value: (~(A ^ value) & (A ^ UInt8(temp & 0xFF)) & 0x80) == 0x80)
        
        // Set negative flag
        setPBit(7, value: ((temp >> 7) & 0x1) == 1)
        
        // Set zero flag
        setPBit(1, value: (temp & 0xFF) == 0)
        
        // Set carry flag
        setPBit(0, value: temp > 255)
        
        A = UInt8(temp & 0xFF)
		        
        writeCycle(address, data: value)
    }
	
    // MARK: Logical
	
    /**
     Bitwise XOR A with Memory
    */
    func EOR(_ mode: AddressingMode) {
        A = A ^ readFromMemoryUsingAddressingMode(mode)
        
        // Set negative flag
        setPBit(7, value: (A >> 7) == 1)
        
        // Set zero flag
        setPBit(1, value: (A == 0))
		
		if(pageCrossed) {
			_ = readCycle(dummyReadAddress)
		}
    }
    
    /**
     Bitwise AND A with Memory
    */
    func AND(_ mode: AddressingMode) {
        A = A & readFromMemoryUsingAddressingMode(mode)
		
        // Set negative flag
        setPBit(7, value: (A >> 7) == 1)
        
        // Set zero flag
        setPBit(1, value: (A == 0))
        
		if pageCrossed {
			_ = readCycle(dummyReadAddress)
		}
    }
    
    /**
     Bitwise OR A with Memory
    */
    func ORA(_ mode: AddressingMode) {
        A = A | readFromMemoryUsingAddressingMode(mode)
        
        // Set negative flag
        setPBit(7, value: (A >> 7) == 1)
        
        // Set zero flag
        setPBit(1, value: (A == 0))
        
		if pageCrossed {
			_ = readCycle(dummyReadAddress)
		}
    }
	
	/**
	 AND immediate with A (unofficial)
	*/
	func ANC() {
		A = A & readFromMemoryUsingAddressingMode(.immediate)
		
		// Set negative flag
		let negative = (A >> 7) & 0x1 == 1
		setPBit(7, value: negative)
		
		// Set zero flag
		setPBit(1, value: (A == 0))
		
		// Set carry flag (if negative)
		setPBit(0, value: negative)
		
		if pageCrossed {
			ppuStep()
		}
	}
	
	/**
	 AND immediate with A, then shift right 1 (unofficial)
	*/
	func ALR() {
		AND(.immediate)
		LSR(.accumulator, dummyRead: false)
	}
	
	/**
	 AND immediate with A, then rotate right 1 (unofficial)
	*/
	func ARR() {
		AND(.immediate)
		ROR(.accumulator, dummyRead: false)
		
		let bit5 = (A >> 5) & 0x1 == 1
		let bit6 = (A >> 6) & 0x1 == 1
		
		if(bit5) {
			if(bit6) {
				// Set carry flag
				setPBit(0, value: true)
				
				// Clear overflow flag
				setPBit(6, value: false)
			} else {
				// Clear carry flag
				setPBit(0, value: false)
				
				// Set overflow flag
				setPBit(6, value: true)
			}
		} else if(bit6) {
			// Set carry flag
			setPBit(0, value: true)
			
			// Set overflow flag
			setPBit(6, value: true)
		} else {
			// Clear carry flag
			setPBit(0, value: false)
			
			// Clear overflow flag
			setPBit(6, value: false)
		}
	}
	
	/**
	 AND immediate with A, then transfer A to X (unofficial)
	*/
	func LXA() {
		let immediate = readFromMemoryUsingAddressingMode(.immediate)
		
		A = immediate
		X = immediate
		
		// Set zero flag
		setPBit(1, value: (A == 0))
		
		// Set negative flag
		setPBit(7, value: (A >> 7) & 0x1 == 1)
	}
	
	/**
	 AND X with A, then subtract immediate from X (unofficial)
	*/
	func AXS() {
		X = A & X
		
		let memoryValue = readFromMemoryUsingAddressingMode(.immediate)
		
		let temp = Int(X) - Int(memoryValue)
		
		// Set carry flag
		setPBit(0, value: temp >= 0)
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1)
		
		// Set zero flag
		setPBit(1, value: (temp & 0xFF) == 0)
		
		X = UInt8(temp & 0xFF)
	}
	
	/**
	 AND X with high byte from Memory (unofficial)
	*/
	func SXA() {
		let address = addressUsingAddressingMode(.absoluteIndexedY)
		
		let high = X & UInt8(((address >> 8) + 1) & 0xFF)
		
		ppuStep()
		
		writeCycle((UInt16(high) << 8) | (address & 0xFF), data: X)
	}
	
	/**
	 AND Y with high byte from Memory (unofficial)
	*/
	func SYA() {
		let address = addressUsingAddressingMode(.absoluteIndexedX)
		
		let high = Y & UInt8(((address >> 8) + 1) & 0xFF)
		
		ppuStep()
		
		writeCycle((UInt16(high) << 8) | (address & 0xFF), data: Y)
	}
	
    // MARK: Flow Control
	
    /**
     Compare A with Memory
    */
    func CMP(_ mode: AddressingMode) {
        let mem = readFromMemoryUsingAddressingMode(mode)
        let temp = Int(A) - Int(mem)
        
        // Set negative flag
        setPBit(7, value: ((temp >> 7) & 0x1) == 1)
        
        // Set zero flag
        setPBit(1, value: (temp == 0))
        
        // Set carry flag
        setPBit(0, value: (A >= mem))
        
		if pageCrossed {
			_ = readCycle(dummyReadAddress)
		}
    }
    
    /**
     Test bits in A with Memory
    */
    func BIT(_ mode: AddressingMode) {
        let mem = readFromMemoryUsingAddressingMode(mode)
        let temp = A & mem
		
        // Set negative flag
        setPBit(7, value: (mem >> 7) == 1)
        
        // Set overflow flag
        setPBit(6, value: ((mem >> 6) & 0x1) == 1)
		
        // Set zero flag
        setPBit(1, value: (temp == 0))
    }
	
	/**
	 Branch if Carry flag is Clear
	*/
	func BCC() {
		ppuStep()
        let relative = UInt16(fetchPC())
		
		if !getPBit(0) {
			ppuStep()
			let newPC = getPC() &+ (relative ^ 0x80) &- 0x80
			
			if !checkPage(newPC) {
				ppuStep()
			}
			
			setPC(newPC)
		}
	}
	
	/**
	 Branch if Carry flag is Set
	*/
	func BCS() {
		ppuStep()
		let relative = UInt16(fetchPC())
		
		if getPBit(0) {
			ppuStep()
			let newPC = getPC() &+ (relative ^ 0x80) &- 0x80
			
			if !checkPage(newPC) {
				ppuStep()
			}
			
			setPC(newPC)
		}
	}
	
	/**
	 Branch if Zero flag is Set
	*/
	func BEQ() {
		ppuStep()
		let relative = UInt16(fetchPC())
		
		if getPBit(1) {
			ppuStep()
			let newPC = getPC() &+ (relative ^ 0x80) &- 0x80
			
			if !checkPage(newPC) {
				ppuStep()
			}
			
			setPC(newPC)
		}
	}
	
	/**
	 Branch if negative flag is set
	*/
	func BMI() {
		ppuStep()
		let relative = UInt16(fetchPC())
		
		if getPBit(7) {
			ppuStep()
			let newPC = getPC() &+ (relative ^ 0x80) &- 0x80
			
			if !checkPage(newPC) {
				ppuStep()
			}
			
			setPC(newPC)
		}
	}
	
	/**
	 Branch if zero flag is clear
	*/
	func BNE() {
		ppuStep()
		let relative = UInt16(fetchPC())
		
		if(!getPBit(1)) {
			ppuStep()
			let newPC = getPC() &+ (relative ^ 0x80) &- 0x80
			
			if(!checkPage(newPC)) {
				ppuStep()
			}
			
			setPC(newPC)
		}
	}
	
	/**
	 Branch if negative flag is clear
	*/
	func BPL() {
		ppuStep()
		let relative = UInt16(fetchPC())
		
		if(!getPBit(7)) {
			ppuStep()
			let newPC = getPC() &+ (relative ^ 0x80) &- 0x80
			
			if(!checkPage(newPC)) {
				ppuStep()
			}
			
			setPC(newPC)
		}
	}
	
	/**
	 Branch if oVerflow flag is Clear
	*/
	func BVC() {
		ppuStep()
		let relative = UInt16(fetchPC())
		
		if(!getPBit(6)) {
			ppuStep()
			let newPC = getPC() &+ (relative ^ 0x80) &- 0x80
			
			if(!checkPage(newPC)) {
				ppuStep()
			}
			
			setPC(newPC)
		}
	}
	
	/**
	 Branch if oVerflow flag is Set
	*/
	func BVS() {
		ppuStep()
		let relative = UInt16(fetchPC())
		
		if(getPBit(6)) {
			ppuStep()
			let newPC = getPC() &+ (relative ^ 0x80) &- 0x80
			
			if(!checkPage(newPC)) {
				ppuStep()
			}
			
			setPC(newPC)
		}
	}
	
	/**
	 ComPare X with Memory
	*/
	func CPX(_ mode: AddressingMode) {
		let mem = readFromMemoryUsingAddressingMode(mode)
		let temp = Int(X) - Int(mem)
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1)
		
		// Set carry flag
		setPBit(0, value: X >= mem)
		
		// Set zero flag
		setPBit(1, value: (temp == 0))
	}
	
	/**
	 ComPare Y with Memory
	*/
	func CPY(_ mode: AddressingMode) {
		let mem = readFromMemoryUsingAddressingMode(mode)
		let temp = Int(Y) - Int(mem)
		
		// Set negative flag
		setPBit(7, value: ((temp >> 7) & 0x1) == 1)
		
		// Set carry flag
		setPBit(0, value: Y >= mem)
		
		// Set zero flag
		setPBit(1, value: (temp == 0))
	}
	
    /**
     No OPeration
    */
    func NOP() {
		ppuStep()
    }
	
	/**
	 Does nothing.  Is supposed to read from memory
	 at the specified address, but is used as a longer
	 NOP here
	*/
	func IGN(_ mode: AddressingMode) {
		_ = readFromMemoryUsingAddressingMode(mode)
		
		if pageCrossed {
			ppuStep()
		}
	}
	
	/**
	 Does nothing.  A NOP that reads the immediate byte
	*/
	func SKB() {
		ppuStep()
		_ = fetchPC()
	}
	
	// MARK: P Register
	
	/**
	 Clear Carry flag
	*/
	func CLC() {
		ppuStep()
		setPBit(0, value: false)
	}
	
	/**
	 Clear Decimal flag
	*/
	func CLD() {
		ppuStep()
		setPBit(3, value: false)
	}
	
	/**
	 Clear Interrupt flag
	*/
	func CLI() {
		ppuStep()
		setPBit(2, value: false)
		interruptDelay = true
	}
	
	/**
	 Clear oVerflow flag
	*/
	func CLV() {
		ppuStep()
		setPBit(6, value: false)
	}
	
	/**
	 Set Carry flag
	*/
	func SEC() {
		ppuStep()
		setPBit(0, value: true)
	}
	
	/**
	 Set Decimal flag
	*/
	func SED() {
		ppuStep()
		setPBit(3, value: true)
	}
	
	/**
	 Set Interrupt flag
	*/
	func SEI() {
		ppuStep()
		setPBit(2, value: true)
	}
}
