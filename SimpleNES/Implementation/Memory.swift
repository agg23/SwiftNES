//
//  Memory.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

class Memory: NSObject {
	/* Main Memory
	-- $10000 --
	 PRG-ROM Upper Bank
	-- $C000 --
	 PRG-ROM Lower Bank
	-- $8000 --
	 SRAM
	-- $6000 --
	 Expansion ROM
	-- $4020 --
	 I/O Registers
	-- $4000 --
	 Mirrors $2000 - $2007
	-- $2008 --
	 I/O Registers
	-- $2000 --
	 Mirrors $0000 - $07FF
	-- $0800 --
	 RAM
	-- $0200 --
	 Stack
	-- $0100 --
	 Zero Page
	-- $0000 --
	*/
	
	/* -- $4000
	 Empty
	-- $3F20 --
	 Sprite Palette
	-- $3F10 --
	 Image Palette
	-- $3F00 --
	 Empty
	-- $3000 --
	 Attribute Table 3
	-- $2FC0 --
	 Name Table 3 (32x30 tiles)
	-- $2C00 --
	 Attribute Table 2
	-- $2BC0 --
	 Name Table 2 (32x30 tiles)
	-- $2800 --
	 Attribute Table 1
	-- $27C0 --
	 Name Table 1 (32x30 tiles)
	-- $2400 --
	 Attribute Table 0
	-- $23C0 --
	 Name Table 0 (32x30 tiles)
	-- $2000 --
	 Pattern Table 1 (256x2x8, may be VROM)
	-- $1000 --
	 Pattern Table 0 (256x2x8, may be VROM)
	-- $0000 --
	*/
	
	var memory: [UInt8];
	
	/**
		True if PPU memory, false if CPU memory
	*/
	let type: Bool;
	
	/**
		Initializes CPU memory
	*/
	override init() {
		self.memory = [UInt8](count: 0x10000, repeatedValue: 0);
		self.type = false;
	}
	
	/**
		Initializes memory with the given type
	
		- Parameter memoryType: The type of memory to create, represented as a Bool.
			True represents PPU memory (VRAM) and false CPU memory
	*/
	init(memoryType: Bool) {
		if(memoryType) {
			self.memory = [UInt8](count: 0x4000, repeatedValue: 0);
			self.type = true;
		} else {
			self.memory = [UInt8](count: 0x10000, repeatedValue: 0);
			self.type = false;
		}
	}
	
	func readMemory(address: Int) -> UInt8 {
		return self.memory[address];
	}
	
	func writeMemory(address: Int, data: UInt8) {
		if((!self.type && (address > 0xFFFF)) || (self.type && address > 0x3FFF)) {
			print("ERROR: Memory address \(address) in out of bounds");
			
			return;
		}
		
		self.memory[address] = data;
	}
	
}
