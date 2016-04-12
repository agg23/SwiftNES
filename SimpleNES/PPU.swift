//
//  PPU.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 4/2/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

struct RGB {
	var value: UInt32
	var r: UInt8 {
		get { return UInt8(value & 0xFF) }
		set { value = UInt32(newValue) | (value & 0xFFFFFF00) }
	}
	var g: UInt8 {
		get { return UInt8((value >> 8) & 0xFF) }
		set { value = (UInt32(newValue) << 8) | (value & 0xFFFF00FF) }
	}
	var b: UInt8 {
		get { return UInt8((value >> 16) & 0xFF) }
		set { value = (UInt32(newValue) << 16) | (value & 0xFF00FFFF) }
	}
	var alpha: UInt8 {
		get { return UInt8((value >> 24) & 0xFF) }
		set { value = (UInt32(newValue) << 24) | (value & 0x00FFFFFF) }
	}
}

func makeRGBArray(array: [UInt32]) -> [RGB] {
	var rgbArray = [RGB](count: array.count, repeatedValue: RGB(value: 0));
	
	for i in 0 ..< array.count {
		rgbArray[i] = RGB(value: 0xFF000000 | array[i]);
	}
	
	return rgbArray;
}

let rawColors: [UInt32] = [0x7C7C7C, 0x0000FC, 0x0000BC, 0x4428BC, 0x940084, 0xA80020, 0xA81000,
				0x881400, 0x503000, 0x007800, 0x006800, 0x005800, 0x004058, 0x000000,
				0x000000, 0x000000, 0xBCBCBC, 0x0078F8, 0x0058F8, 0x6844FC, 0xD800CC,
				0xE40058, 0xF83800, 0xE45C10, 0xAC7C00, 0x00B800, 0x00A800, 0x00A844,
				0x008888, 0x000000, 0x000000, 0x000000, 0xF8F8F8, 0x3CBCFC, 0x6888FC,
				0x9878F8, 0xF878F8, 0xF85898, 0xF87858, 0xFCA044, 0xF8B800, 0xB8F818,
				0x58D854, 0x58F898, 0x00E8D8, 0x787878, 0x000000, 0x000000, 0xFCFCFC,
				0xA4E4FC, 0xB8B8F8, 0xD8B8F8, 0xF8B8F8, 0xF8A4C0, 0xF0D0B0, 0xFCE0A8,
				0xF8D878, 0xD8F878, 0xB8F8B8, 0xB8F8D8, 0x00FCFC, 0xF8D8F8, 0x000000,
				0x000000];

let colors = makeRGBArray(rawColors);

class PPU: NSObject {
	/**
	 PPU Control Register
	*/
	var PPUCTRL: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2000] = PPUCTRL;
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (PPUCTRL & 0x1F);
		}
	}
	
	/**
	 PPU Mask Register
	*/
	var PPUMASK: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2001] = PPUMASK;
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (PPUMASK & 0x1F);
		}
	}

	/**
	 PPU Status Register
	*/
	var PPUSTATUS: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2002] = PPUSTATUS;
		}
	}
	
	/**
	 OAM Address Port
	*/
	var OAMADDR: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2003] = OAMADDR;
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (OAMADDR & 0x1F);
		}
	}
	
	/**
	 OAM Data Port
	*/
	var OAMDATA: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2004] = OAMDATA;
			self.writeOAMDATA = true;
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (OAMDATA & 0x1F);
		}
	}
	
	/**
	 PPU Scrolling Position Register
	*/
	var PPUSCROLL: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2005] = PPUSCROLL;
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (PPUSCROLL & 0x1F);
		}
	}
	
	/**
	 PPU Address Register
	*/
	var PPUADDR: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2006] = PPUADDR;
			
			if(self.writeVRAMHigh) {
				self.vramAddress = (UInt16(PPUADDR) << 8) | (self.vramAddress & 0xFF);
			} else {
				self.vramAddress = (self.vramAddress & 0xFF00) | UInt16(PPUADDR);
			}
			
			self.writeVRAMHigh = !self.writeVRAMHigh;
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (PPUADDR & 0x1F);
		}
	}
	
	/**
	 PPU Data Port
	*/
	var PPUDATA: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2007] = PPUDATA;
			self.ppuMemory.writeMemory(Int(self.vramAddress), data: PPUDATA);
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (PPUDATA & 0x1F);
			
			// Increment VRAM address
			if(getBit(2, pointer: &self.PPUCTRL)) {
				self.vramAddress += 32;
			} else {
				self.vramAddress += 1;
			}
		}
	}
	
	/*
	 OAM DMA Register
	*/
	var OAMDMA: UInt8 {
		didSet {
			self.cpuMemory.writeMemory(0x4014, data: OAMDMA);
			dmaCopy();
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (OAMDMA & 0x1F);
		}
	}
	
	/**
	 Used to indicate whether OAMDATA needs to be written
	*/
	var writeOAMDATA: Bool;
	
	/**
	 Stores the VRAM address pointed to with the help of PPUADDR
	*/
	var vramAddress: UInt16;
	
	/**
	 Indicates whether a given PPUADDR write is the high or low byte
	*/
	var writeVRAMHigh: Bool;
	
	/**
	 Stores the current scanline of the PPU
	*/
	var scanline: Int;
	
	/**
	 Stores the current pixel of the PPU
	*/
	var pixelIndex: Int;
	
	/**
	 Stores the current frame data to be drawn to the screen
	*/
	var frame: [RGB];
	
	var cycle: Int;
	
	var initFrame = true;
	
	var evenFrame = true;
		
	var cpu: CPU?;
	let cpuMemory: Memory;
	let ppuMemory: Memory;
	let oamMemory: Memory;
	
	// MARK: Stored Values Between Cycles -
	var nameTable: UInt8;
	var attributeTable: UInt8;
	var patternTableLow: UInt8;
	var patternTableHigh: UInt8;
	
	// MARK: Methods -
	
	init(cpuMemory: Memory, ppuMemory: Memory) {
		self.cpu = nil;
		
		self.cpuMemory = cpuMemory;
		self.ppuMemory = ppuMemory;
		self.oamMemory = Memory(memoryType: Memory.MemoryType.OAM);
		
		self.writeOAMDATA = false;
		self.vramAddress = 0;
		self.writeVRAMHigh = true;
		
		self.PPUCTRL = 0;
		self.PPUMASK = 0;
		//self.PPUSTATUS = 0xA0;
		self.PPUSTATUS = 0;
		self.OAMADDR = 0;
		self.OAMDATA = 0;
		self.PPUSCROLL = 0;
		self.PPUADDR = 0;
		self.PPUDATA = 0;
		self.OAMDMA = 0;
		
		self.scanline = 241;
		self.pixelIndex = 0;
		
		self.cycle = 0;
		
		self.nameTable = 0;
		self.attributeTable = 0;
		self.patternTableLow = 0;
		self.patternTableHigh = 0;
		
		let pixel = RGB(value: 0xFF000000);
		
		self.frame = [RGB](count:256 * 240, repeatedValue:pixel);
	}
	
	func reset() {
		
	}
	
	func step() -> Bool {
		if(self.scanline >= 240) {
			// VBlank period
			
			if(self.scanline == 241 && self.cycle == 1) {
				if(!self.initFrame) {
					// Set VBlank flag
					setBit(7, value: true, pointer: &self.PPUSTATUS);
				} else {
					self.initFrame = false;
				}
				
				if((self.PPUCTRL & 0x80) == 0x80) {
					// NMI enabled
					self.cpu!.queueInterrupt(CPU.Interrupt.VBlank);
				}
			}
			
			// Skip tick on odd frame
			if(!self.evenFrame && self.scanline == 261 && self.cycle == 339) {
				self.cycle = 0;
				
				self.scanline = -1;
				
				return true;
			}
			
			// TODO: Handle glitchy increment on non-VBlank scanlines as referenced:
			// http://wiki.nesdev.com/w/index.php/PPU_registers
			if(self.writeOAMDATA) {
				self.writeOAMDATA = false;
				
				self.oamMemory.writeMemory(Int(self.OAMADDR), data: self.OAMDATA);
				
				self.OAMADDR += 1;
				
				if(getBit(2, pointer: &self.PPUCTRL)) {
					self.OAMADDR = self.OAMADDR + 32;
				} else {
					self.OAMADDR = self.OAMADDR + 1;
				}
			}
		} else if(self.scanline == -1) {
			// TODO: Update horizontal and vertical scroll counters
			
			if(self.cycle == 1) {
				// Clear VBlank flag
				setBit(7, value: false, pointer: &self.PPUSTATUS);
			}
		} else {
			// Visible scanlines
			
			if(self.cycle == 0) {
				// Do nothing
			} else if(self.cycle <= 256 && getBit(3, pointer: &self.PPUMASK)) {
				// If rendering cycle and rendering background bit is set
				let tileIndex = self.cycle / 8;
				let phaseIndex = self.cycle % 8;
				
				if(phaseIndex == 2) {
					// Fetch Name Table
					self.nameTable = self.ppuMemory.readMemory(0x2000 + self.scanline / 8 * 32 + tileIndex);
				} else if(phaseIndex == 4) {
					// Fetch Attribute Table
					self.attributeTable = self.ppuMemory.readMemory(0x23C0 + tileIndex / 2 + (self.scanline / 4) * 8);
				} else if(phaseIndex == 6) {
					// Fetch lower Pattern Table byte
					self.patternTableLow = self.ppuMemory.readMemory(0x0000 + Int(nameTable));
				} else if(phaseIndex == 0) {
					// Fetch upper Pattern Table byte
					self.patternTableHigh = self.ppuMemory.readMemory(0x0000 + Int(nameTable) + 8);
					
//					if(nameTable != 0) {
//						print("Nametable is \(nameTable) with pattern tables \(self.patternTableLow) \(self.patternTableHigh) on \(self.scanline * 256 + self.cycle - 8)");
//					}
					
					// Draw pixels from tile
					for k in 0 ..< 8 {
						let lowBit = getBit(k, pointer: &self.patternTableLow) ? 1 : 0;
						let highBit = getBit(k, pointer: &self.patternTableHigh) ? 1 : 0;
						
						// TODO: Incorrect color
						self.frame[self.scanline * 256 + self.cycle - 8 + k] = colors[(highBit << 1) | lowBit];
					}
				}
			} else if(self.cycle <= 320) {
				// TODO: Fetch tile data for sprites on next scanline
			} else if(self.cycle <= 336) {
				// TODO: Fetch tile data for first two tiles on next scanline
			} else {
				// TODO: Fetch garbage Name Table byte
			}
		}
		
		self.cycle += 1;
		
		if(self.cycle == 341) {
			self.cycle = 0;
			if(self.scanline == 260) {
				// Frame completed
				self.scanline = -1;
				
				self.evenFrame = !self.evenFrame;
				
				return true;
			} else {
				scanline += 1;
			}
		}
		
		return false;
	}
	
	func renderScanline() -> Bool {
		if(scanline < 20) {
			self.frame[534] = RGB(value: 0xFF0000FF);
			// VBlank period
			if(scanline == 1) {
				
				// Set VBlank flag
				setBit(7, value: true, pointer: &self.PPUSTATUS);
				
				if((self.PPUCTRL & 0x80) == 0x80) {
					// NMI enabled
					self.cpu!.queueInterrupt(CPU.Interrupt.VBlank);
				}
			}
			
			if(self.writeOAMDATA) {
				self.writeOAMDATA = false;
				
				self.oamMemory.writeMemory(Int(self.OAMADDR), data: self.OAMDATA);
				
				self.OAMADDR += 1;
				
				if(getBit(2, pointer: &self.PPUCTRL)) {
					self.OAMADDR = self.OAMADDR + 32;
				} else {
					self.OAMADDR = self.OAMADDR + 1;
				}
			}
			
			
			scanline += 1;
			return false;
		} else if(scanline == 20) {
			// TODO: Update horizontal and vertical scroll counters
			
			// Clear VBlank flag
			setBit(7, value: false, pointer: &self.PPUSTATUS);
			
			scanline += 1;
			return false;
		} else if(scanline == 261) {
			scanline = 0;
			return true;
		}
		
		let scanlineIndex = self.scanline - 21;
		
		// Load playfield
		for i in 0 ..< 32 {
			let nameTable = self.ppuMemory.readMemory(0x2000 + scanlineIndex / 8 * 32 + i);
			let attributeTable = self.ppuMemory.readMemory(0x23C0 + i / 2 + (scanlineIndex / 4) * 8);
			
			var patternTableBitmapLow = self.ppuMemory.readMemory(0x0000 + Int(nameTable));
			var patternTableBitmapHigh = self.ppuMemory.readMemory(0x0000 + Int(nameTable) + 8);
			
//			if(nameTable != 0) {
//				print("Nametable is \(nameTable) with pattern tables \(patternTableBitmapLow) \(patternTableBitmapHigh)");
//			}
			
			for k in 0 ..< 8 {
				let lowBit = getBit(k, pointer: &patternTableBitmapLow) ? 1 : 0;
				let highBit = getBit(k, pointer: &patternTableBitmapHigh) ? 1 : 0;
				
				// TODO: Incorrect
				self.frame[(self.scanline - 21) * 256 + i * 8 + k] = colors[(highBit << 1) | lowBit];
			}
		}
		
		// Load objects for next scanline
		for i in 0 ..< 8 {
			// TODO: Load objects
		}
		
		// Load first two tiles of playfield for next scanline
		for i in 0 ..< 2 {
			let nameTable = self.ppuMemory.readMemory(0x2000 + scanline / 8 + i);
			let attributeTable = self.ppuMemory.readMemory(0x23C0 + i);
			
			let patternTableOne = self.ppuMemory.readMemory(0x0000 + Int(nameTable));
			let patternTableTwo = self.ppuMemory.readMemory(0x1000 + Int(nameTable));
		}
		
		scanline += 1;
		
		return false;
	}
	
	// MARK - Registers
	
	func setBit(index: Int, value: Bool, pointer: UnsafeMutablePointer<UInt8>) {
		let bit: UInt8 = value ? 0xFF : 0;
		pointer.memory ^= (bit ^ pointer.memory) & (1 << UInt8(index));
	}
	
	func getBit(index: Int, pointer: UnsafePointer<UInt8>) -> Bool {
		return ((pointer.memory >> UInt8(index)) & 0x1) == 1;
	}
	
	func readPPUSTATUS() -> UInt8 {
		let temp = self.PPUSTATUS;
		
		// Clear VBlank flag
		setBit(7, value: false, pointer: &self.PPUSTATUS);
		
		// Clear PPUSCROLL and PPUADDR
		self.PPUSCROLL = 0;
		self.PPUADDR = 0;
		
		return temp;
	}
	
	func readPPUDATA() -> UInt8 {
		self.PPUDATA = self.ppuMemory.readMemory(Int(self.vramAddress));
		return self.PPUDATA;
	}
	
	func dmaCopy() -> Int {
		let address = Int((UInt16(self.OAMDMA) << 8) & 0xFF00);
		
		for i in 0 ..< 256 {
			self.oamMemory.writeMemory(Int((UInt16(self.OAMADDR) + UInt16(i)) & 0xFF), data: self.cpuMemory.readMemory(address + i));
		}
		
		// TODO: Block CPU for 513-514 cycles while copy is occuring
		
		return 513;
	}
}