//
//  Mapper9.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/30/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Mapper9: Mapper {
	private var prgBankOffset: Int
	private var prgBankLastOffset: Int
	
	private var chrBank0Offset: Int
	private var chrBank1Offset: Int
	
	private var latch0: Bool
	private var latch1: Bool
	private var chrBank0FD: Int
	private var chrBank0FE: Int
	private var chrBank1FD: Int
	private var chrBank1FE: Int
	
	override var cpuMemory: CPUMemory! {
		didSet {
			prgBankLastOffset = cpuMemory.banks.count - 0x2000
		}
	}
	
	override init() {
		prgBankOffset = 0
		prgBankLastOffset = 0
		
		chrBank0Offset = 0
		chrBank1Offset = 0
		
		latch0 = false
		latch1 = false
		chrBank0FD = 0
		chrBank0FE = 0
		chrBank1FD = 0
		chrBank1FE = 0
	}
	
	override func read(_ address: UInt16) -> UInt8 {
		switch address {
			case 0x0000 ..< 0x1000:
				let temp = ppuMemory.banks[chrBank0Offset + address]
				
				if address == 0xFD8 {
					latch0 = false
					updateCHRBanks()
				} else if address == 0xFE8 {
					latch0 = true
					updateCHRBanks()
				}
				
				return temp
			case 0x1000 ..< 0x2000:
				let temp = ppuMemory.banks[chrBank1Offset + address - 0x1000]
				if address > 0x1FD7 && address < 0x1FE0 {
					latch1 = false
					updateCHRBanks()
				} else if address > 0x1FE7 && address < 0x1FF0 {
					latch1 = true
					updateCHRBanks()
				}
				
				return temp
			case 0x2000 ..< 0x6000:
				print("Invalid mapper 9 address \(address)")
			case 0x6000 ..< 0x8000:
				return cpuMemory.sram[address - 0x6000]
			case 0x8000 ..< 0xA000:
				return cpuMemory.banks[prgBankOffset + address - 0x8000]
			case 0xA000 ..< 0xC000:
				return cpuMemory.banks[prgBankLastOffset + address - 0xE000]
			case 0xC000 ..< 0xE000:
				return cpuMemory.banks[prgBankLastOffset + address - 0xE000]
			case 0xE000 ... 0xFFFF:
				return cpuMemory.banks[prgBankLastOffset + address - 0xE000]
			default:
				break
		}
		
		return 0
	}
	
	override func write(_ address: UInt16, data: UInt8) {
		switch address {
			case 0x0000 ..< 0x1000:
				ppuMemory.banks[chrBank0Offset + address] = data
			case 0x1000 ..< 0x2000:
				ppuMemory.banks[chrBank1Offset + address - 0x1000] = data
			case 0x2000 ..< 0x6000:
				print("Invalid mapper 9 address \(address)")
			case 0x6000 ..< 0x8000:
				cpuMemory.sram[address - 0x6000] = data
			case 0x8000 ..< 0xA000:
				print("Invalid mapper 9 address \(address)")
			case 0xA000 ..< 0xB000:
				setPRGBank(data)
			case 0xB000 ..< 0xC000:
				chrBank0FD = Int(data) & 0x1F
				updateCHRBanks()
			case 0xC000 ..< 0xD000:
				chrBank0FE = Int(data) & 0x1F
				updateCHRBanks()
			case 0xD000 ..< 0xE000:
				chrBank1FD = Int(data) & 0x1F
				updateCHRBanks()
			case 0xE000 ..< 0xF000:
				chrBank1FE = Int(data) & 0x1F
				updateCHRBanks()
			case 0xF000 ... 0xFFFF:
				setMirroring(data)
			default:
				break
		}
	}
	
	func setPRGBank(_ data: UInt8) {
		prgBankOffset = (Int(data) & 0xF) * 0x2000
	}
	
	func updateCHRBanks() {
		if latch0 {
			// FE
			chrBank0Offset = chrBank0FE * 0x1000
		} else {
			// FD
			chrBank0Offset = chrBank0FD * 0x1000
		}
		
		if latch1 {
			// FE
			chrBank1Offset = chrBank1FE * 0x1000
		} else {
			// FD
			chrBank1Offset = chrBank1FD * 0x1000
		}
	}
	
	func setMirroring(_ data: UInt8) {
		if data & 0x1 == 0x1 {
			ppuMemory.nametableMirroring = .horizontal
		} else {
			ppuMemory.nametableMirroring = .vertical
		}
	}
}
