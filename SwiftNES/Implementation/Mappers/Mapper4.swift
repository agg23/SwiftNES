//
//  Mapper4.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/31/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Mapper4: Mapper {
	
	override var cpuMemory: CPUMemory! {
		didSet {
			prgBankLastOffset = UInt16(cpuMemory.banks.count - 0x2000)
			
			updateOffsets()
		}
	}
	
	
	private var register0: UInt8
	private var register1: UInt8
	private var register2: UInt8
	private var register3: UInt8
	private var register4: UInt8
	private var register5: UInt8
	private var register6: UInt8
	private var register7: UInt8
	
	private var irqLoadRegister: UInt8
	private var irqCounter: UInt8
	private var irqShouldReload: Bool
	private var irqDisable: Bool
	
	private var prgBank0: UInt8
	private var prgBank1: UInt8
	private var prgBank2: UInt8
	
	private var prgBank0Offset: UInt16
	private var prgBank1Offset: UInt16
	private var prgBank2Offset: UInt16
	private var prgBankLastOffset: UInt16
	
	private var chrBank0Offset: UInt16
	private var chrBank1Offset: UInt16
	private var chrBank2Offset: UInt16
	private var chrBank3Offset: UInt16
	private var chrBank4Offset: UInt16
	private var chrBank5Offset: UInt16
	private var chrBank6Offset: UInt16
	private var chrBank7Offset: UInt16
	
	private var selectedBank: Int
	private var prgBankMode: Bool
	private var chrBankMode: Bool
	
	override init() {
		register0 = 0
		register1 = 0
		register2 = 0
		register3 = 0
		register4 = 0
		register5 = 0
		register6 = 0
		register7 = 0
		
		irqLoadRegister = 0
		irqCounter = 0
		irqShouldReload = false
		irqDisable = true
		
		prgBank0 = 0
		prgBank1 = 0
		prgBank2 = 0
		
		prgBank0Offset = 0
		prgBank1Offset = 0
		prgBank2Offset = 0
		prgBankLastOffset = 0
		
		chrBank0Offset = 0
		chrBank1Offset = 0
		chrBank2Offset = 0
		chrBank3Offset = 0
		chrBank4Offset = 0
		chrBank5Offset = 0
		chrBank6Offset = 0
		chrBank7Offset = 0
		
		selectedBank = 0
		prgBankMode = false
		chrBankMode = false
	}
	
	override func read(_ address: UInt16) -> UInt8 {
		switch address {
			case 0x0000 ..< 0x400:
				return ppuMemory.banks[chrBank0Offset + address]
			case 0x400 ..< 0x800:
				return ppuMemory.banks[chrBank1Offset + address - 0x400]
			case 0x800 ..< 0xC00:
				return ppuMemory.banks[chrBank2Offset + address - 0x800]
			case 0xC00 ..< 0x1000:
				return ppuMemory.banks[chrBank3Offset + address - 0xC00]
			case 0x1000 ..< 0x1400:
				return ppuMemory.banks[chrBank4Offset + address - 0x1000]
			case 0x1400 ..< 0x1800:
				return ppuMemory.banks[chrBank5Offset + address - 0x1400]
			case 0x1800 ..< 0x1C00:
				return ppuMemory.banks[chrBank6Offset + address - 0x1800]
			case 0x1C00 ..< 0x2000:
				return ppuMemory.banks[chrBank7Offset + address - 0x1C00]
			case 0x2000 ..< 0x6000:
				print("Invalid mapper 4 address \(address)")
			case 0x6000 ..< 0x8000:
				return cpuMemory!.sram[address - 0x6000]
			case 0x8000 ..< 0xA000:
				return cpuMemory!.banks[prgBank0Offset + address - 0x8000]
			case 0xA000 ..< 0xC000:
				return cpuMemory.banks[prgBank1Offset + address - 0xA000]
			case 0xC000 ..< 0xE000:
				return cpuMemory.banks[prgBank2Offset + address - 0xC000]
			case 0xE000 ... 0xFFFF:
				return cpuMemory.banks[prgBankLastOffset + address - 0xE000]
			default:
				break
		}
		
		return 0
	}
	
	override func write(_ address: UInt16, data: UInt8) {
		switch address {
			case 0x0000 ..< 0x400:
				ppuMemory.banks[chrBank0Offset + address] = data
			case 0x800 ..< 0x1000:
				ppuMemory.banks[chrBank1Offset + address - 0x800] = data
			case 0x1000 ..< 0x1400:
				ppuMemory.banks[chrBank2Offset + address - 0x1000] = data
			case 0x1400 ..< 0x1800:
				ppuMemory.banks[chrBank3Offset + address - 0x1400] = data
			case 0x1800 ..< 0x1C00:
				ppuMemory.banks[chrBank4Offset + address - 0x1800] = data
			case 0x1C00 ..< 0x2000:
				ppuMemory.banks[chrBank5Offset + address - 0x1C00] = data
			case 0x2000 ..< 0x6000:
				print("Invalid mapper 4 address \(address)")
			case 0x6000 ..< 0x8000:
				cpuMemory.sram[address - 0x6000] = data
			case 0x8000 ..< 0xA000:
				if address % 2 == 0 {
					bankSelect(data)
				} else {
					bankData(data)
				}
			case 0xA000 ..< 0xC000:
				if address % 2 == 0 {
					setMirroring(data)
				} else {
					// TODO: Handle PRG RAM protection
				}
			case 0xC000 ..< 0xE000:
				if address % 2 == 0 {
					irqLoadRegister = data
				} else {
					irqCounter = 0
				}
			case 0xE000 ... 0xFFFF:
				if address % 2 == 0 {
					irqDisable = true
					cpuMemory.ppu?.cpu.clearIRQ()
				} else {
					irqDisable = false
				}
			default:
				break
		}
	}
	
	private func bankSelect(_ data: UInt8) {
		selectedBank = Int(data & 0x7)
		
		prgBankMode = data & 0x40 == 0x40
		chrBankMode = data & 0x80 == 0x80
	}
	
	private func bankData(_ data: UInt8) {
		switch selectedBank {
			case 0:
				register0 = data
			case 1:
				register1 = data
			case 2:
				register2 = data
			case 3:
				register3 = data
			case 4:
				register4 = data
			case 5:
				register5 = data
			case 6:
				register6 = data
			case 7:
				register7 = data
			default:
				break
		}
		
		updateOffsets()
	}
	
	private func setMirroring(_ data: UInt8) {
		if ppuMemory.nametableMirroring != .fourScreen {
			if data & 0x1 == 0x1 {
				ppuMemory.nametableMirroring = .horizontal
			} else {
				ppuMemory.nametableMirroring = .vertical
			}
		}
	}
	
	private func updateOffsets() {
		if chrBankMode {
			chrBank0Offset = UInt16(register2) * 0x400
			chrBank1Offset = UInt16(register3) * 0x400
			chrBank2Offset = UInt16(register4) * 0x400
			chrBank3Offset = UInt16(register5) * 0x400
			chrBank4Offset = UInt16(register0 & 0xFE) * 0x400
			chrBank5Offset = UInt16(register0 | 0x1) * 0x400
			chrBank6Offset = UInt16(register1 & 0xFE) * 0x400
			chrBank7Offset = UInt16(register1 | 0x1) * 0x400
		} else {
			chrBank0Offset = UInt16(register0 & 0xFE) * 0x400
			chrBank1Offset = UInt16(register0 | 0x1) * 0x400
			chrBank2Offset = UInt16(register1 & 0xFE) * 0x400
			chrBank3Offset = UInt16(register1 | 0x1) * 0x400
			chrBank4Offset = UInt16(register2) * 0x400
			chrBank5Offset = UInt16(register3) * 0x400
			chrBank6Offset = UInt16(register4) * 0x400
			chrBank7Offset = UInt16(register5) * 0x400
		}
		
		if prgBankMode {
			prgBank0Offset = prgBankLastOffset - 0x2000
			prgBank2Offset = UInt16(register6) * 0x2000
		} else {
			prgBank0Offset = UInt16(register6) * 0x2000
			prgBank2Offset = prgBankLastOffset - 0x2000
		}
		
		prgBank1Offset = UInt16(register7) * 0x2000
	}
	
	// MARK: - IRQ Handling
	
	override func step() {
		if irqCounter == 0 {
			if irqLoadRegister == 0 {
				cpuMemory.ppu?.cpu.queueIRQ()
			}
			irqCounter = irqLoadRegister
		} else {
			irqCounter -= 1
			
			if irqCounter == 0 && !irqDisable {
				cpuMemory.ppu?.cpu.queueIRQ()
			}
		}
	}
}
