//
//  Mapper11.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/30/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Mapper11: Mapper {
	private var prgBankOffset: Int;
	private var chrBankOffset: Int;
	
	override init() {
		self.prgBankOffset = 0;
		self.chrBankOffset = 0;
	}
	
	override func read(_ address: Int) -> UInt8 {
		switch(address) {
			case 0x0000 ..< 0x2000:
				return self.ppuMemory!.banks[self.chrBankOffset + address];
			case 0x2000 ..< 0x8000:
				print("Invalid mapper 11 address \(address)");
			case 0x8000 ..< 0x10000:
				return self.cpuMemory!.banks[self.prgBankOffset + address - 0x8000];
			default:
				break;
		}
		
		return 0;
	}
	
	override func write(_ address: Int, data: UInt8) {
		switch(address) {
			case 0x0000 ..< 0x2000:
				self.ppuMemory!.banks[self.chrBankOffset + address] = data;
			case 0x2000 ..< 0x8000:
				print("Invalid mapper 11 address \(address)");
			case 0x8000 ..< 0x10000:
				bankSelect(data);
			default:
				break;
		}
	}
	
	func bankSelect(_ data: UInt8) {
		self.prgBankOffset = (Int(data) & 0x3) * 0x8000;
		self.chrBankOffset = ((Int(data) & 0xF0) >> 4) * 0x2000;
	}
}
