//
//  Mapper2.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/30/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Mapper2: Mapper {
	
	private var prgBank0Offset: Int;
	private var prgBank1Offset: Int;
	
	override var cpuMemory: CPUMemory? {
		didSet {
			self.prgBank1Offset = cpuMemory!.banks.count - 0x4000 - 0xC000;
		}
	}
	
	override init() {
		self.prgBank0Offset = 0;
		self.prgBank1Offset = 0;
	}
	
	override func read(_ address: Int) -> UInt8 {
		switch(address) {
			case 0x0000 ..< 0x2000:
				return self.ppuMemory!.banks[address];
			case 0x2000 ..< 0x8000:
				print("Invalid mapper 2 address \(address)");
			case 0x8000 ..< 0xC000:
				return self.cpuMemory!.banks[self.prgBank0Offset + address - 0x8000];
			case 0xC000 ..< 0x10000:
				// - 0xC000 performed in cpuMemory setter for optimization
				return self.cpuMemory!.banks[self.prgBank1Offset + address];
			default:
				break;
		}
		
		return 0;
	}
	
	override func write(_ address: Int, data: UInt8) {
		switch(address) {
			case 0x0000 ..< 0x2000:
				self.ppuMemory!.banks[address] = data;
			case 0x2000 ..< 0x8000:
				print("Invalid mapper 2 address \(address)");
			case 0x8000 ..< 0x10000:
				bankSelect(data);
			default:
				break;
		}
	}
	
	func bankSelect(_ data: UInt8) {
		self.prgBank0Offset = (Int(data) & 0xF) * 0x4000;
	}
}
