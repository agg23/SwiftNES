//
//  Mapper7.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/30/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Mapper7: Mapper {
	private var prgBankOffset: Int;
	
	override init() {
		self.prgBankOffset = 0;
	}
	
	override func read(address: Int) -> UInt8 {
		switch(address) {
			case 0x0000 ..< 0x2000:
				return self.ppuMemory!.banks[address];
			case 0x2000 ..< 0x8000:
				print("Invalid mapper 7 address \(address)");
			case 0x8000 ..< 0x10000:
				return self.cpuMemory!.banks[self.prgBankOffset + address - 0x8000];
			default:
				break;
		}
		
		return 0;
	}
	
	override func write(address: Int, data: UInt8) {
		switch(address) {
			case 0x0000 ..< 0x2000:
				self.ppuMemory!.banks[address] = data;
			case 0x2000 ..< 0x8000:
				print("Invalid mapper 7 address \(address)");
			case 0x8000 ..< 0x10000:
				bankSelect(data);
			default:
				break;
		}
	}
	
	func bankSelect(data: UInt8) {
		self.prgBankOffset = (Int(data) & 0x7) * 0x8000;
		
		self.ppuMemory!.oneScreenUpper = data & 0x10 == 0x10;
	}
}