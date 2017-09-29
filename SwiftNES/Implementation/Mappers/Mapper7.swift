//
//  Mapper7.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/30/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Mapper7: Mapper {
	private var prgBankOffset: Int
	
	override init() {
		prgBankOffset = 0
	}
	
	override func read(_ address: Int) -> UInt8 {
		switch address {
			case 0x0000 ..< 0x2000:
				return ppuMemory.banks[address]
			case 0x2000 ..< 0x8000:
				print("Invalid mapper 7 address \(address)")
			case 0x8000 ..< 0x10000:
				return cpuMemory.banks[prgBankOffset + address - 0x8000]
			default:
				break
		}
		
		return 0
	}
	
	override func write(_ address: Int, data: UInt8) {
		switch address {
			case 0x0000 ..< 0x2000:
				ppuMemory.banks[address] = data
			case 0x2000 ..< 0x8000:
				print("Invalid mapper 7 address \(address)")
			case 0x8000 ..< 0x10000:
				bankSelect(data)
			default:
				break
		}
	}
	
	func bankSelect(_ data: UInt8) {
		prgBankOffset = (Int(data) & 0x7) * 0x8000
		
		ppuMemory.oneScreenUpper = data & 0x10 == 0x10
	}
}
