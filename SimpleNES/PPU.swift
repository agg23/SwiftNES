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
	var alpha: UInt8 {
		get { return UInt8((value >> 24) & 0xFF) }
		set { value = (UInt32(newValue) << 24) | (value & 0x00FFFFFF) }
	}
	var r: UInt8 {
		get { return UInt8((value >> 16) & 0xFF) }
		set { value = (UInt32(newValue) << 16) | (value & 0xFF00FFFF) }
	}
	var g: UInt8 {
		get { return UInt8((value >> 8) & 0xFF) }
		set { value = (UInt32(newValue) << 8) | (value & 0xFFFF00FF) }
	}
	var b: UInt8 {
		get { return UInt8(value & 0xFF) }
		set { value = UInt32(newValue) | (value & 0xFFFFFF00) }
	}
}

struct Sprite {
	var patternTableLow: UInt8;
	var patternTableHigh: UInt8;
	var attribute: UInt8;
	var xCoord: UInt8;
}

func makeRGBArray(array: [UInt32]) -> [RGB] {
	var rgbArray = [RGB](count: array.count, repeatedValue: RGB(value: 0));
	
	for i in 0 ..< array.count {
		rgbArray[i] = RGB(value: array[i]);
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
			self.cpuMemory.memory[0x4014] = OAMDMA;
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
	
	var secondaryOAM = [UInt8](count: 32, repeatedValue: 0);
	
	// MARK: Stored Values Between Cycles -
	var nameTable: UInt8;
	var attributeTable: UInt8;
	var patternTableLow: UInt8;
	var patternTableHigh: UInt8;
	
	var currentSpriteData = [Sprite](count: 8, repeatedValue: Sprite(patternTableLow: 0xFF, patternTableHigh: 0xFF, attribute: 0, xCoord: 0));
	
	var oamByte: UInt8;
	
	var oamStage = 0;
	var oamIndex = 0;
	var secondaryOAMIndex = 0;
	
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
		
		self.oamByte = 0;
		
		let pixel = RGB(value: 0);
		
		self.frame = [RGB](count:256 * 240, repeatedValue:pixel);
	}
	
	func reset() {
		
	}
	
	func step() -> Bool {
		if(self.scanline >= 240) {
			// VBlank period
			
			if(self.scanline == 241 && self.cycle == 1) {
//				self.cpu?.logger.log("VBlank");
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
			
			let phaseIndex = self.cycle % 8;
			
			if(self.cycle == 0) {
				self.oamStage = 0;
				self.oamIndex = 0;
				self.secondaryOAMIndex = 0;
				
				// Do nothing
			} else if(self.cycle <= 256 && getBit(3, pointer: &self.PPUMASK)) {
				// Render sprites
				if(self.cycle <= 64) {
					// Set secondary OAM to 0xFF
					if(self.cycle % 2 == 0) {
						self.secondaryOAM[self.cycle / 2 - 1] = 0xFF;
					}
				} else if(self.cycle <= 256) {
					if(self.oamStage == 0) {
						if(self.cycle % 2 == 0) {
							
							self.secondaryOAM[self.secondaryOAMIndex] = self.oamByte;
							
							let intOAMByte = Int(self.oamByte);
							let intScanline = Int(self.scanline);
							
							if(intOAMByte <= intScanline && intOAMByte + 8 > intScanline) {
								
								if(self.secondaryOAMIndex >= 32) {
									// TODO: Handle overflow
								} else {
									// Sprite should be drawn on this line
									self.secondaryOAM[self.secondaryOAMIndex + 1] = self.oamMemory.readMemory(4 * self.oamIndex + 1);
									self.secondaryOAM[self.secondaryOAMIndex + 2] = self.oamMemory.readMemory(4 * self.oamIndex + 2);
									self.secondaryOAM[self.secondaryOAMIndex + 3] = self.oamMemory.readMemory(4 * self.oamIndex + 3);
									
									self.secondaryOAMIndex += 4;
								}
							}
							self.oamIndex += 1;
							
							if(self.oamIndex >= 64) {
								self.oamIndex = 0;
								self.oamStage = 1;
							}
							
						} else {
							self.oamByte = self.oamMemory.readMemory(4 * self.oamIndex);
						}
					}
				}
				
				
				// If rendering cycle and rendering background bit is set
				let tileIndex = (self.cycle - 1) / 8;
				let patternRow = self.scanline % 8;
				let tileRow = self.scanline / 8;
				
				var baseNameTableAddress = 0x2000;
				
				if(getBit(0, pointer: &self.PPUCTRL)) {
					if(getBit(1, pointer: &self.PPUCTRL)) {
						baseNameTableAddress = 0x2C00;
					} else {
						baseNameTableAddress = 0x2400;
					}
				} else {
					if(getBit(1, pointer: &self.PPUCTRL)) {
						baseNameTableAddress = 0x2800;
					}
				}
				
				if(phaseIndex == 2) {
					// Fetch Name Table
					self.nameTable = self.ppuMemory.readMemory(baseNameTableAddress + self.scanline / 8 * 32 + tileIndex);
				} else if(phaseIndex == 4) {
					// Fetch Attribute Table
					self.attributeTable = self.ppuMemory.readMemory(baseNameTableAddress + 0x3C0 + tileIndex / 4 + (self.scanline / 8 / 4) * 8);
				} else if(phaseIndex == 6) {
					// Fetch lower Pattern Table byte
					var basePatternTableAddress = 0x0000;
					
					if(getBit(4, pointer: &self.PPUCTRL)) {
						basePatternTableAddress = 0x1000;
					}
					
					self.patternTableLow = self.ppuMemory.readMemory(basePatternTableAddress + (Int(nameTable) << 4) + patternRow);
				} else if(phaseIndex == 0) {
					// Fetch upper Pattern Table byte
					var basePatternTableAddress = 0x0008;
					
					if(getBit(4, pointer: &self.PPUCTRL)) {
						basePatternTableAddress = 0x1008;
					}
					
					self.patternTableHigh = self.ppuMemory.readMemory(basePatternTableAddress + (Int(nameTable) << 4) + patternRow);
					
					// Draw pixels from tile
					for k in 0 ..< 8 {
						let lowBit = getBit(7 - k, pointer: &self.patternTableLow) ? 1 : 0;
						let highBit = getBit(7 - k, pointer: &self.patternTableHigh) ? 1 : 0;
						
						let attributeShift = (tileIndex % 4) / 2 + ((tileRow % 4) / 2) * 2;
						
						let attributeBits = (Int(self.attributeTable) >> (attributeShift * 2)) & 0x3;
						
						let patternValue = (attributeBits << 2) | (highBit << 1) | lowBit;
												
						let paletteIndex = Int(self.ppuMemory.readMemory(0x3F00 + patternValue));
						
						let pixelXCoord = self.cycle - 8 + k;
						
						self.frame[self.scanline * 256 + pixelXCoord] = colors[paletteIndex];
					}
				}
				
				if(self.cycle == 256) {
					// Handle sprites, in reverse order in order to properly overlap
					for j in 0 ..< 8 {
						var sprite = currentSpriteData[7 - j];
						let xCoord = Int(sprite.xCoord);
						
						if(xCoord >= 0xFF) {
							continue;
						}
						
						for x in 0 ..< 8 {
							let lowBit = getBit(7 - x, pointer: &sprite.patternTableLow) ? 1 : 0;
							let highBit = getBit(7 - x, pointer: &sprite.patternTableHigh) ? 1 : 0;
							
							let attributeBits = Int(sprite.attribute) & 0x3;
							
							let patternValue = (attributeBits << 2) | (highBit << 1) | lowBit;
							
							let paletteIndex = Int(self.ppuMemory.readMemory(0x3F10 + patternValue));
							
							// First color each section of sprite palette is transparent
							if(patternValue % 4 == 0) {
								continue;
							}
							
							// TODO: Handle behind background priority
							// TODO: X coordinate of sprites is off slightly
							
							self.frame[self.scanline * 256 + xCoord + x] = colors[paletteIndex];
						}
					}
				}
			} else if(self.cycle <= 320) {
				if(self.cycle == 257) {
					self.secondaryOAMIndex = 0;
				}
				
				if(phaseIndex == 0 && self.secondaryOAMIndex < 32) {
					let yCoord = self.secondaryOAM[secondaryOAMIndex];
					let tileNumber = self.secondaryOAM[secondaryOAMIndex + 1];
					var attributes = self.secondaryOAM[secondaryOAMIndex + 2];
					let xCoord = self.secondaryOAM[secondaryOAMIndex + 3];
					
					var yShift = self.scanline - Int(yCoord);
					
					// TODO: Handle 8x8 sprites
					var basePatternTableAddress = 0x0000;
					
					if(getBit(3, pointer: &self.PPUCTRL)) {
						basePatternTableAddress = 0x1000;
					}
					
					// Flip sprite vertically
					if(getBit(7, pointer: &attributes)) {
						yShift = 7 - yShift;
					}
					
					var patternTableLow = self.ppuMemory.readMemory(basePatternTableAddress + (Int(tileNumber) << 4) + yShift);
					var patternTableHigh = self.ppuMemory.readMemory(basePatternTableAddress + (Int(tileNumber) << 4) + yShift + 8);
					
					// Flip sprite horizontally
					if(getBit(6, pointer: &attributes)) {
						patternTableLow = reverseByte(patternTableLow);
						patternTableHigh = reverseByte(patternTableHigh);
					}
					
					currentSpriteData[self.secondaryOAMIndex / 4] = Sprite(patternTableLow: patternTableLow, patternTableHigh: patternTableHigh, attribute: attributes, xCoord: xCoord);
					
					self.secondaryOAMIndex += 4;
				}
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
	
	// MARK - Registers
	
	func setBit(index: Int, value: Bool, pointer: UnsafeMutablePointer<UInt8>) {
		let bit: UInt8 = value ? 0xFF : 0;
		pointer.memory ^= (bit ^ pointer.memory) & (1 << UInt8(index));
	}
	
	func getBit(index: Int, pointer: UnsafePointer<UInt8>) -> Bool {
		return ((pointer.memory >> UInt8(index)) & 0x1) == 1;
	}
	
	/**
	 Bit level reverses the given byte
	 From http://stackoverflow.com/a/2602885
	*/
	func reverseByte(value: UInt8) -> UInt8 {
		var b = (value & 0xF0) >> 4 | (value & 0x0F) << 4;
		b = (b & 0xCC) >> 2 | (b & 0x33) << 2;
		b = (b & 0xAA) >> 1 | (b & 0x55) << 1;
		return b;
	}
	
	func readPPUSTATUS() -> UInt8 {
		let temp = self.PPUSTATUS;
		
		// Clear VBlank flag
		setBit(7, value: false, pointer: &self.PPUSTATUS);
		
		// Clear PPUSCROLL and PPUADDR
		self.PPUSCROLL = 0;
		self.PPUADDR = 0;
		
		// Reset PPUADDR write high byte
		self.writeVRAMHigh = true;
		
		return temp;
	}
	
	func readPPUDATA() -> UInt8 {
		self.PPUDATA = self.ppuMemory.readMemory(Int(self.vramAddress));
		return self.PPUDATA;
	}
	
	func dmaCopy() {
		let address = Int((UInt16(self.OAMDMA) << 8) & 0xFF00);
		
		for i in 0 ..< 255 {
			self.oamMemory.writeMemory(Int((UInt16(self.OAMADDR) + UInt16(i)) & 0xFF), data: self.cpuMemory.readMemory(address + i));
		}
		
		self.cpu!.startOAMTransfer();
	}
}