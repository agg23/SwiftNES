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
	
	enum MemoryType {
		case CPU
		
		case PPU
		
		case OAM
	}
	
	enum NametableMirroringType {
		case Vertical
		
		case Horizontal
		
		case OneScreen
		
		case FourScreen
	}
	
	private var memory: [UInt8];
	
	var mirrorPRGROM = false;
	
	/**
	 Stores the type of this Memory object
	*/
	private let type: MemoryType;
	
	var nametableMirroring: NametableMirroringType = .OneScreen;
	
	var ppu: PPU?;
	var controllerIO: ControllerIO?;
	
	/**
	 Initializes CPU memory
	*/
	override convenience init() {
		self.init(memoryType: MemoryType.CPU);
	}
	
	/**
	 Initializes memory with the given type

	 - Parameter memoryType: The type of memory to create, represented as a Bool.
		True represents PPU memory (VRAM) and false CPU memory
	*/
	init(memoryType: MemoryType) {
		if(memoryType == MemoryType.PPU) {
			self.memory = [UInt8](count: 0x4000, repeatedValue: 0);
		} else if(memoryType == MemoryType.CPU) {
			self.memory = [UInt8](count: 0x10000, repeatedValue: 0);
		} else {
			self.memory = [UInt8](count: 0x100, repeatedValue: 0);
		}
		
		self.type = memoryType;
		
		self.ppu = nil;
	}
	
	func readMemory(address: Int) -> UInt8 {
		var address = address;
		if(self.type == MemoryType.CPU) {
			if((address >= 0x2000) && (address < 0x4000)) {
				switch (address % 8) {
					case 0:
						return (self.ppu?.readWriteOnlyRegister())!;
					case 1:
						return (self.ppu?.readWriteOnlyRegister())!;
					case 2:
						return (self.ppu?.readPPUSTATUS())!;
					case 3:
						return (self.ppu?.readWriteOnlyRegister())!;
					case 4:
						return (self.ppu?.readOAMDATA())!;
					case 5:
						return (self.ppu?.readWriteOnlyRegister())!;
					case 6:
						return (self.ppu?.readWriteOnlyRegister())!;
					case 7:
						return (self.ppu?.readPPUDATA())!;
					default: break
				}
			} else if(address == 0x4016) {
				return self.controllerIO!.readState();
			} else if(self.mirrorPRGROM && address >= 0xC000) {
				return self.memory[0x8000 + address % 0xC000];
			}
		} else if(self.type == MemoryType.PPU) {
			address = address % 0x4000;
			if((address >= 0x2000) && (address < 0x3000)) {
				if(self.nametableMirroring == .OneScreen) {
					address = 0x2000 | (address % 0x200);
				} else if(self.nametableMirroring == .Horizontal) {
					if(address >= 0x2C00) {
						address -= 0x800;
					} else if(address >= 0x2400) {
						address -= 0x400;
					}
				} else if(self.nametableMirroring == .Vertical) {
					if(address >= 0x2800) {
						address -= 0x800;
					}
				} else {
					print("ERROR: Nametable mirroring type not implemented");
				}
			} else if((address > 0x2FFF) && (address < 0x3F00)) {
				address -= 0x1000;
			} else if(address >= 0x3F10) {
				address = 0x3F00 + address % 0x20;
				
				if((address >= 0x3F10) && (address < 0x3F20) && (address & 0x3 == 0)) {
					address -= 0x10;
				}
			}
		}
		
		return self.memory[address];
	}
	
	func readTwoBytesMemory(address: Int) -> UInt16 {
		return UInt16(self.readMemory(address + 1)) << 8 | UInt16(self.readMemory(address));
	}
	
	func writeMemory(address: Int, data: UInt8) {
		var address = address;
		
		if((self.type == MemoryType.CPU && (address > 0xFFFF))) {
			print("ERROR: Memory address \(address) out of bounds for Memory: \(self.type)");
			
			return;
		}
		
		if(self.type == MemoryType.CPU) {
			if((address >= 0x2000) && (address < 0x4000)) {
				self.ppu?.cpuWrite(address % 8, data: data);
			} else if(address == 0x4014) {
				self.ppu?.OAMDMA = data;
			} else if(address == 0x4016) {
				if(data & 0x1 == 1) {
					self.controllerIO?.strobeHigh = true;
				} else {
					self.controllerIO?.strobeHigh = false;
				}
			} else if(self.mirrorPRGROM && address >= 0xC000) {
				self.memory[0x8000 + address % 0xC000] = data;
			}
		} else if(self.type == MemoryType.PPU) {
			address = address % 0x4000;
			if((address >= 0x2000) && (address < 0x3000)) {
				if(self.nametableMirroring == .OneScreen) {
					address = 0x2000 | (address % 0x200);
				} else if(self.nametableMirroring == .Horizontal) {
					if(address >= 0x2C00) {
						address -= 0x800;
					} else if(address >= 0x2400) {
						address -= 0x400;
					}
				} else if(self.nametableMirroring == .Vertical) {
					if(address >= 0x2800) {
						address -= 0x800;
					}
				} else {
					print("ERROR: Nametable mirroring type not implemented");
				}
			} else if((address > 0x2FFF) && (address < 0x3F00)) {
				address -= 0x1000;
			} else if(address >= 0x3F10) {
				address = 0x3F00 + address % 0x20;
				
				if((address >= 0x3F10) && (address < 0x3F20) && (address & 0x3 == 0)) {
					address -= 0x10;
				}
			}
		}
		
		self.memory[address] = data;
	}
	
    func writeTwoBytesMemory(address: Int, data: UInt16) {
        writeMemory(address, data: UInt8(data & 0xFF));
        writeMemory(address + 1, data: UInt8((data & 0xFF00) >> 8));
    }
}
