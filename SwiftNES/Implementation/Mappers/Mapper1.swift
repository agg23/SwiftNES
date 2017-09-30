//
//  Mapper1.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/25/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Mapper1: Mapper {
	
	// MARK: - Internal Registers
	
	private var shiftRegister: UInt8
	private var control: UInt8 {
		didSet {
			let mirroring = control & 0x3
			
			switch mirroring {
				case 0:
					ppuMemory.nametableMirroring = .oneScreen
					ppuMemory.oneScreenUpper = false
				case 1:
					ppuMemory.nametableMirroring = .oneScreen
					ppuMemory.oneScreenUpper = true
				case 2:
					ppuMemory.nametableMirroring = .vertical
				case 3:
					ppuMemory.nametableMirroring = .horizontal
				default:
					break
			}
			
			prgRomBankMode = (control & 0xC) >> 2
			chrRomBankMode = control & 0x10 == 0x10
			
			updateOffsets()
		}
	}
	
	private var prgRomBankMode: UInt8
	private var chrRomBankMode: Bool
	
	private var chrBank0: UInt8
	private var chrBank1: UInt8
	
	private var prgBank: UInt8
	private var prgRAMEnabled: Bool
	
	private var chrBank0Offset: Int
	private var chrBank1Offset: Int
	private var prgBank0Offset: Int
	private var prgBank1Offset: Int
	
	override var cpuMemory: CPUMemory! {
		didSet {
			prgBank1Offset = cpuMemory.banks.count - 0x4000
		}
	}
	
	override var ppuMemory: PPUMemory! {
		didSet {
			let count = ppuMemory.banks.count
			
			if count == 0 {
				chrBank1Offset = 0x1000
			} else {
				chrBank1Offset = ppuMemory.banks.count - 0x4000
			}
		}
	}
	
	override init() {
		shiftRegister = 0x10
		control = 0
		
		prgRomBankMode = 0
		chrRomBankMode = false
		
		chrBank0 = 0
		chrBank1 = 1
		
		prgBank = 0
		prgRAMEnabled = true
		
		chrBank0Offset = 0
		chrBank1Offset = 0x1000
		prgBank0Offset = 0
		prgBank1Offset = 0
	}
	
	override func read(_ address: UInt16) -> UInt8 {
		switch address {
			case 0x0000 ..< 0x1000:
				return ppuMemory.banks[chrBank0Offset + address]
			case 0x1000 ..< 0x2000:
				return ppuMemory.banks[chrBank1Offset + address - 0x1000]
			case 0x2000 ..< 0x6000:
				print("Invalid mapper 1 address \(address)")
			case 0x6000 ..< 0x8000:
				if prgRAMEnabled {
					return cpuMemory!.sram[address - 0x6000]
				} else {
					return 0
				}
			case 0x8000 ..< 0xC000:
				return self.cpuMemory.banks[prgBank0Offset + address - 0x8000]
			case 0xC000 ... 0xFFFF:
				return self.cpuMemory.banks[prgBank1Offset + address - 0xC000]
			default:
				break
		}
		
		return 0
	}
	
	override func write(_ address: UInt16, data: UInt8) {
		switch(address) {
			case 0x0000 ..< 0x1000:
				ppuMemory.banks[chrBank0Offset + address] = data
			case 0x1000 ..< 0x2000:
				ppuMemory.banks[chrBank1Offset + address - 0x1000] = data
			case 0x2000 ..< 0x6000:
				print("Invalid mapper 1 address \(address)")
			case 0x6000 ..< 0x8000:
				cpuMemory.sram[address - 0x6000] = data
			case 0x8000 ... 0xFFFF:
				updateShiftRegister(address, data: data)
			default:
				break
		}
	}
	
	private func updateShiftRegister(_ address: UInt16, data: UInt8) {
		if data & 0x80 == 0x80 {
			shiftRegister = 0x10
			control = control | 0x0C
		} else {
			let writeComplete = shiftRegister & 0x1 == 0x1
			shiftRegister = shiftRegister >> 1
			shiftRegister = shiftRegister | ((data & 0x1) << 4)
			
			if writeComplete {
				writeInternalRegister(address, data: data)
				shiftRegister = 0x10
			}
		}
	}
	
	private func writeInternalRegister(_ address: UInt16, data: UInt8) {
		if address < 0xA000 {
			// Control
			control = shiftRegister
		} else if address < 0xC000 {
			// CHR bank 0
			chrBank0 = shiftRegister & (chrBankCount - 1)
		} else if address < 0xE000 {
			// CHR bank 1
			chrBank1 = shiftRegister & (chrBankCount - 1)
		} else {
			// PRG bank
			prgBank = shiftRegister & 0xF & (prgBankCount - 1)
			prgRAMEnabled = shiftRegister & 0x10 == 0
		}
		
		updateOffsets()
	}
	
	private func updateOffsets() {
		if chrRomBankMode {
			chrBank0Offset = Int(chrBank0) * 0x1000
			chrBank1Offset = Int(chrBank1) * 0x1000
		} else {
			chrBank0Offset = Int(chrBank0 & 0xFE) * 0x1000
			chrBank1Offset = chrBank0Offset + 0x1000
		}
		
		switch prgRomBankMode {
			case 0, 1:
				prgBank0Offset = Int(prgBank & 0xFE) * 0x4000
				prgBank1Offset = prgBank0Offset + 0x4000
			case 2:
				prgBank0Offset = 0
				prgBank1Offset = Int(prgBank) * 0x4000
			case 3:
				prgBank0Offset = Int(prgBank) * 0x4000
				prgBank1Offset = cpuMemory.banks.count - 0x4000
			default:
				break
		}
	}
}
