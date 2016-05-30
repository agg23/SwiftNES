//
//  Mapper.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/25/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

class Mapper {
	var cpuMemory: CPUMemory?;
	var ppuMemory: PPUMemory?;
	
	var chrBankCount: UInt8;
	var prgBankCount: UInt8;
	
	init() {
		self.cpuMemory = nil;
		self.ppuMemory = nil;
		
		self.chrBankCount = 0;
		self.prgBankCount = 0;
	}
	
	func read(address: Int) -> UInt8 {
		switch(address) {
			case 0x0000 ..< 0x1000:
				return self.ppuMemory!.banks[address];
			case 0x1000 ..< 0x2000:
				return self.ppuMemory!.banks[address];
			case 0x2000 ..< 0x6000:
//				print("Invalid mapper 0 address \(address)");
				break;
			case 0x6000 ..< 0x8000:
				return self.cpuMemory!.sram[address - 0x6000];
			case 0x8000 ..< 0xC000:
				return self.cpuMemory!.banks[address - 0x8000];
			case 0xC000 ..< 0x10000:
				return self.cpuMemory!.banks[address - 0x8000];
			default:
				break;
		}
		
		return 0;
	}
	
	func write(address: Int, data: UInt8) {
		switch(address) {
			case 0x0000 ..< 0x1000:
				self.ppuMemory!.banks[address] = data;
			case 0x1000 ..< 0x2000:
				self.ppuMemory!.banks[address] = data;
			case 0x2000 ..< 0x6000:
//				print("Invalid mapper 0 address \(address)");
				break;
			case 0x6000 ..< 0x8000:
				self.cpuMemory!.sram[address - 0x6000] = data;
			case 0x8000 ..< 0xC000:
				self.cpuMemory!.banks[address - 0x8000] = data;
			case 0xC000 ..< 0x10000:
				self.cpuMemory!.banks[address - 0x8000] = data;
			default:
				break;
		}
	}
}
