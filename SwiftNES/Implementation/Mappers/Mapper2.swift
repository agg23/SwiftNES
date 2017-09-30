//
//  Mapper2.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/30/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Mapper2: Mapper {
	
	private var prgBank0Offset: UInt16
	private var prgBank1Offset: UInt16
	
	override var cpuMemory: CPUMemory! {
		didSet {
			prgBank1Offset = UInt16(cpuMemory.banks.count - 0x4000 - 0xC000)
		}
	}
	
	override init() {
		prgBank0Offset = 0
		prgBank1Offset = 0
	}
	
	override func read(_ address: UInt16) -> UInt8 {
		switch address {
			case 0x0000 ..< 0x2000:
				return ppuMemory.banks[address]
			case 0x2000 ..< 0x8000:
				print("Invalid mapper 2 address \(address)")
			case 0x8000 ..< 0xC000:
				return cpuMemory.banks[prgBank0Offset + address - 0x8000]
			case 0xC000 ... 0xFFFF:
				// - 0xC000 performed in cpuMemory setter for optimization
				return cpuMemory.banks[prgBank1Offset + address]
			default:
				break
		}
		
		return 0
	}
	
	override func write(_ address: UInt16, data: UInt8) {
		switch address {
			case 0x0000 ..< 0x2000:
				ppuMemory.banks[address] = data
			case 0x2000 ..< 0x8000:
				print("Invalid mapper 2 address \(address)")
			case 0x8000 ... 0xFFFF:
				bankSelect(data)
			default:
				break
		}
	}
	
	func bankSelect(_ data: UInt8) {
		prgBank0Offset = (UInt16(data) & 0xF) * 0x4000
	}
}
