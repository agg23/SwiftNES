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
	
	init() {
		self.cpuMemory = nil;
		self.ppuMemory = nil;
	}
	
	func ppuRead(address: Int) -> UInt8 {
		return self.ppuMemory!.banks[address];
	}
	
	func ppuWrite(address: Int, data: UInt8) {
		self.ppuMemory!.banks[address] = data;
	}
	
	func cpuRead(address: Int) -> UInt8 {
		return self.cpuMemory!.banks[address];
	}
	
	func cpuWrite(address: Int, data: UInt8) {
		self.cpuMemory!.banks[address] = data;
	}
}
