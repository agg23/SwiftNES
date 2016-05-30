//
//  Mapper3.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/30/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Mapper3: Mapper {
	
	private var chrBankOffset: Int;
	
	override init() {
		self.chrBankOffset = 0;
	}
	
	override func read(address: Int) -> UInt8 {
		switch(address) {
			case 0x0000 ..< 0x2000:
				return self.ppuMemory!.banks[self.chrBankOffset + address];
			case 0x2000 ..< 0x8000:
				print("Invalid mapper 3 address \(address)");
			case 0x8000 ..< 0x10000:
				return self.cpuMemory!.banks[address - 0x8000];
			default:
				break;
		}
		
		return 0;
	}
	
	override func write(address: Int, data: UInt8) {
		switch(address) {
			case 0x0000 ..< 0x2000:
				self.ppuMemory!.banks[self.chrBankOffset + address] = data;
			case 0x2000 ..< 0x8000:
				print("Invalid mapper 3 address \(address)");
			case 0x8000 ..< 0x10000:
				bankSelect(data);
			default:
				break;
		}
	}
	
	func bankSelect(data: UInt8) {
		self.chrBankOffset = Int(data) * 0x2000;
	}
}