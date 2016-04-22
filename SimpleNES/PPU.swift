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
	/**
	 Stores the NES color index (ignored when drawing)
	*/
	var colorIndex: UInt8 {
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
	var yCoord: UInt8;
}

func makeRGBArray(array: [UInt32]) -> [RGB] {
	var rgbArray = [RGB](count: array.count, repeatedValue: RGB(value: 0));
	
	for i in 0 ..< array.count {
		rgbArray[i] = RGB(value: array[i]);
	}
	
	return rgbArray;
}

private let rawColors: [UInt32] = [0x7C7C7C, 0x0000FC, 0x0000BC, 0x4428BC, 0x940084, 0xA80020, 0xA81000,
				0x881400, 0x503000, 0x007800, 0x006800, 0x005800, 0x004058, 0x000000,
				0x000000, 0x000000, 0xBCBCBC, 0x0078F8, 0x0058F8, 0x6844FC, 0xD800CC,
				0xE40058, 0xF83800, 0xE45C10, 0xAC7C00, 0x00B800, 0x00A800, 0x00A844,
				0x008888, 0x000000, 0x000000, 0x000000, 0xF8F8F8, 0x3CBCFC, 0x6888FC,
				0x9878F8, 0xF878F8, 0xF85898, 0xF87858, 0xFCA044, 0xF8B800, 0xB8F818,
				0x58D854, 0x58F898, 0x00E8D8, 0x787878, 0x000000, 0x000000, 0xFCFCFC,
				0xA4E4FC, 0xB8B8F8, 0xD8B8F8, 0xF8B8F8, 0xF8A4C0, 0xF0D0B0, 0xFCE0A8,
				0xF8D878, 0xD8F878, 0xB8F8B8, 0xB8F8D8, 0x00FCFC, 0xF8D8F8, 0x000000,
				0x000000];

private let colors = makeRGBArray(rawColors);

class PPU: NSObject {
	/**
	 PPU Control Register
	*/
	var PPUCTRL: UInt8 {
		didSet {
			// Update tempVramAddress
			self.tempVramAddress = (self.tempVramAddress & 0xF3FF) | ((UInt16(PPUCTRL) & 0x03) << 10);
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (PPUCTRL & 0x1F);
		}
	}
	
	/**
	 PPU Mask Register
	*/
	var PPUMASK: UInt8 {
		didSet {
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (PPUMASK & 0x1F);
		}
	}

	/**
	 PPU Status Register
	*/
	var PPUSTATUS: UInt8;
	
	/**
	 OAM Address Port
	*/
	var OAMADDR: UInt8 {
		didSet {
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (OAMADDR & 0x1F);
		}
	}
	
	/**
	 OAM Data Port
	*/
	var OAMDATA: UInt8 {
		didSet {
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
			if(self.writeToggle) {
				// Second write
				self.tempVramAddress = (self.tempVramAddress & 0x8FFF) | ((UInt16(PPUSCROLL) & 0x7) << 12);
				self.tempVramAddress = (self.tempVramAddress & 0xFC1F) | ((UInt16(PPUSCROLL) & 0xF8) << 2);
			} else {
				self.tempVramAddress = (self.tempVramAddress & 0xFFE0) | (UInt16(PPUSCROLL) >> 3);
				self.fineXScroll = PPUSCROLL & 0x7;
			}
			
			self.writeToggle = !self.writeToggle;
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (PPUSCROLL & 0x1F);
		}
	}
	
	/**
	 PPU Address Register
	*/
	var PPUADDR: UInt8 {
		didSet {
			if(self.writeToggle) {
				// Second write
				self.tempVramAddress = (self.tempVramAddress & 0xFF00) | UInt16(PPUADDR);
				self.currentVramAddress = self.tempVramAddress;
			} else {
				self.tempVramAddress = (self.tempVramAddress & 0x80FF) | ((UInt16(PPUADDR) & 0x3F) << 8);
			}
			
			self.writeToggle = !self.writeToggle;
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (PPUADDR & 0x1F);
		}
	}
	
	/**
	 PPU Data Port
	*/
	var PPUDATA: UInt8 {
		didSet {
			self.ppuMemory.writeMemory(Int(self.currentVramAddress), data: PPUDATA);
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (PPUDATA & 0x1F);
			
			// Increment VRAM address
			if(getBit(2, pointer: &self.PPUCTRL)) {
				self.currentVramAddress += 32;
			} else {
				self.currentVramAddress += 1;
			}
			
			self.currentVramAddress = self.currentVramAddress & 0x7FFF;
		}
	}
	
	/*
	 OAM DMA Register
	*/
	var OAMDMA: UInt8 {
		didSet {
			dmaCopy();
			
			// Update residual lower bits in PPUSTATUS
			PPUSTATUS = (PPUSTATUS & 0xE0) | (OAMDMA & 0x1F);
		}
	}
	
	/**
	 Used to indicate whether OAMDATA needs to be written
	*/
	private var writeOAMDATA: Bool;
	
	/**
	 Stores the current scanline of the PPU
	*/
	private var scanline: Int;
	
	/**
	 Stores the current pixel of the PPU
	*/
	private var pixelIndex: Int;
	
	/**
	 Stores the current frame data to be drawn to the screen
	*/
	var frame: [RGB];
	
	private var cycle: Int;
	
	private var initFrame = true;
	
	private var evenFrame = true;
		
	var cpu: CPU?;
	private let cpuMemory: Memory;
	private let ppuMemory: Memory;
	private let oamMemory: Memory;
	
	private var secondaryOAM = [UInt8](count: 32, repeatedValue: 0);
	
	/**
	 Buffers PPUDATA reads
	*/
	private var ppuDataReadBuffer: UInt8;
	
	/**
	 Any write to a PPU register will set this value
	*/
	private var lastWrittenRegisterValue: UInt8;
	
	private var currentVramAddress: UInt16;
	private var tempVramAddress: UInt16;
	private var fineXScroll: UInt8;
	private var writeToggle: Bool;
	
	
	// MARK: Stored Values Between Cycles -
	private var nameTable: UInt8;
	private var attributeTable: UInt8;
	private var patternTableLow: UInt8;
	private var patternTableHigh: UInt8;
	
	private var currentSpriteData = [Sprite](count: 8, repeatedValue: Sprite(patternTableLow: 0xFF, patternTableHigh: 0xFF, attribute: 0, xCoord: 0, yCoord: 0));
	
	private var oamByte: UInt8;
	
	private var oamStage = 0;
	private var oamIndex = 0;
	private var oamIndexOverflow = 0;
	private var secondaryOAMIndex = 0;
	
	// MARK: Methods -
	
	init(cpuMemory: Memory, ppuMemory: Memory) {
		self.cpu = nil;
		
		self.cpuMemory = cpuMemory;
		self.ppuMemory = ppuMemory;
		self.oamMemory = Memory(memoryType: Memory.MemoryType.OAM);
		
		self.writeOAMDATA = false;
		
		self.currentVramAddress = 0;
		self.tempVramAddress = 0;
		self.fineXScroll = 0;
		self.writeToggle = false;
		
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
		
		self.ppuDataReadBuffer = 0;
		self.lastWrittenRegisterValue = 0;
		
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
		if(self.cycle > 256) {
			self.OAMADDR = 0;
		}
		
		if(self.cycle == 256 && (getBit(3, pointer: &self.PPUMASK) || getBit(4, pointer: &self.PPUMASK))) {
			incrementY();
		} else if(self.cycle == 257 && (getBit(3, pointer: &self.PPUMASK) || getBit(4, pointer: &self.PPUMASK))) {
			copyX();
		}
		
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
				
				if(getBit(2, pointer: &self.PPUCTRL)) {
					self.OAMADDR = UInt8((Int(self.OAMADDR) + 32) & 0xFF);
				} else {
					self.OAMADDR = UInt8((Int(self.OAMADDR) + 1) & 0xFF);
				}
			}
		} else if(self.scanline == -1) {
			// TODO: Update horizontal and vertical scroll counters
			
			if(self.cycle == 1) {
				// Clear sprite overflow flag
				setBit(5, value: false, pointer: &self.PPUSTATUS);
				
				// Clear sprite 0 hit flag
				setBit(6, value: false, pointer: &self.PPUSTATUS);
				
				// Clear VBlank flag
				setBit(7, value: false, pointer: &self.PPUSTATUS);
			}
			
			if(self.cycle == 304 && (getBit(3, pointer: &self.PPUMASK) || getBit(4, pointer: &self.PPUMASK))) {
				copyY();
			}
		} else {
			// Visible scanlines
			
			let phaseIndex = self.cycle % 8;
			
			if(self.cycle == 0) {
				self.oamStage = 0;
				self.oamIndex = 0;
				self.oamIndexOverflow = 0;
				self.secondaryOAMIndex = 0;
				
				// Do nothing
			} else if(self.cycle <= 256) {
				// Do sprite calculations whether or not draw sprite bit is set
				
				if(self.cycle <= 64) {
					// Set secondary OAM to 0xFF
					if(self.cycle % 2 == 0) {
						self.secondaryOAM[self.cycle / 2 - 1] = 0xFF;
					}
				} else if(self.cycle <= 256) {
					if(self.oamStage == 0) {
						if(self.cycle % 2 == 0) {
							
							let intOAMByte = Int(self.oamByte);
							let intScanline = Int(self.scanline);
							
							var spriteHeight = 8;
							
							if(getBit(5, pointer: &self.PPUCTRL)) {
								spriteHeight = 16;
							}
							
							if(intOAMByte <= intScanline && intOAMByte + spriteHeight > intScanline) {
								
								if(self.secondaryOAMIndex >= 32) {
									if(getBit(3, pointer: &self.PPUMASK) || getBit(4, pointer: &self.PPUMASK)) {
										// TODO: Handle overflow
										setBit(5, value: true, pointer: &self.PPUSTATUS);
									}
								} else {
									// Sprite should be drawn on this line
									self.secondaryOAM[self.secondaryOAMIndex] = self.oamByte;
									self.secondaryOAM[self.secondaryOAMIndex + 1] = self.oamMemory.readMemory(4 * self.oamIndex + 1);
									self.secondaryOAM[self.secondaryOAMIndex + 2] = self.oamMemory.readMemory(4 * self.oamIndex + 2);
									self.secondaryOAM[self.secondaryOAMIndex + 3] = self.oamMemory.readMemory(4 * self.oamIndex + 3);
									
									self.secondaryOAMIndex += 4;
								}
							} else if(self.secondaryOAMIndex >= 32) {
								self.oamIndexOverflow += 1;
								
								if(self.oamIndexOverflow >= 4) {
									self.oamIndexOverflow = 0;
								}
							}
							
							self.oamIndex += 1;
							
							if(self.oamIndex >= 64) {
								self.oamIndex = 0;
								self.oamStage = 1;
								
								while(self.secondaryOAMIndex < 32) {
									self.secondaryOAM[self.secondaryOAMIndex] = 0xFF;
									self.secondaryOAM[self.secondaryOAMIndex + 1] = 0xFF;
									self.secondaryOAM[self.secondaryOAMIndex + 2] = 0xFF;
									self.secondaryOAM[self.secondaryOAMIndex + 3] = 0xFF;
									
									self.secondaryOAMIndex += 4;
								}
							}
							
						} else {
							self.oamByte = self.oamMemory.readMemory(4 * self.oamIndex + self.oamIndexOverflow);
						}
					}
				}
				
				if(getBit(4, pointer: &self.PPUMASK)) {
					// Render sprites
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
								
								let address = self.scanline * 256 + xCoord + x;
								
								if(address >= 256 * 240) {
									// TODO: Fix
									continue;
								}
								
								let backgroundPixel = self.frame[address];
								
								if(j == 7 && getBit(3, pointer: &self.PPUMASK) && backgroundPixel.colorIndex & 0x3 != 0 && paletteIndex & 0x3 != 0) {
									// Sprite 0 and Background is not transparent
									
									// If bits 1 or 2 in PPUMASK are clear and the x coordinate is between 0 and 7, don't hit
									// If x coordinate is 255 or greater, don't hit
									// If y coordinate is 239 or greater, don't hit
									if(!((!getBit(1, pointer: &self.PPUMASK) || !getBit(2, pointer: &self.PPUMASK)) && xCoord + x < 8)
										&& xCoord + x < 255
										&& sprite.yCoord < 239) {
										setBit(6, value: true, pointer: &self.PPUSTATUS);
									}
								}
								
								self.frame[address] = colors[paletteIndex];
							}
						}
					}
				}
				
				if(getBit(3, pointer: &self.PPUMASK)) {
					// If rendering cycle and rendering background bit is set
					let tileIndex = (self.cycle - 1) / 8;
					let patternRow = self.scanline % 8;
					let tileRow = self.scanline / 8;
					
//					var baseNameTableAddress = 0x2000;
					
//					if(getBit(0, pointer: &self.PPUCTRL)) {
//						if(getBit(1, pointer: &self.PPUCTRL)) {
//							baseNameTableAddress = 0x2C00;
//						} else {
//							baseNameTableAddress = 0x2400;
//						}
//					} else {
//						if(getBit(1, pointer: &self.PPUCTRL)) {
//							baseNameTableAddress = 0x2800;
//						}
//					}
					
					if(phaseIndex == 2) {
						// Fetch Name Table
						self.nameTable = self.ppuMemory.readMemory(0x2000 | (Int(self.currentVramAddress) & 0x0FFF));
					} else if(phaseIndex == 4) {
						// Fetch Attribute Table
						let currentVramAddress = Int(self.currentVramAddress);
						self.attributeTable = self.ppuMemory.readMemory(0x23C0 | (currentVramAddress & 0x0C00) | ((currentVramAddress >> 4) & 0x38) | ((currentVramAddress >> 2) & 0x07));
					} else if(phaseIndex == 6) {
						// Fetch lower Pattern Table byte
						var basePatternTableAddress = 0x0000;
						
						if(getBit(4, pointer: &self.PPUCTRL)) {
							basePatternTableAddress = 0x1000;
						}
						
						let fineY = (Int(self.currentVramAddress) >> 12) & 7;
						
						self.patternTableLow = self.ppuMemory.readMemory(basePatternTableAddress + (Int(self.nameTable) << 4) + fineY);
					} else if(phaseIndex == 0) {
						// Fetch upper Pattern Table byte
						var basePatternTableAddress = 0x0008;
						
						if(getBit(4, pointer: &self.PPUCTRL)) {
							basePatternTableAddress = 0x1008;
						}
						
						let fineY = (Int(self.currentVramAddress) >> 12) & 7;
						
						self.patternTableHigh = self.ppuMemory.readMemory(basePatternTableAddress + (Int(self.nameTable) << 4) + fineY);
						
						// Draw pixels from tile
						for k in 0 ..< 8 {
							let lowBit = getBit(7 - k, pointer: &self.patternTableLow) ? 1 : 0;
							let highBit = getBit(7 - k, pointer: &self.patternTableHigh) ? 1 : 0;
							
							let attributeShift = Int(((self.currentVramAddress >> 4) & 4) | (self.currentVramAddress & 2));
							
							let attributeBits = (Int(self.attributeTable) >> attributeShift) & 0x3;
							
							var patternValue = (attributeBits << 2) | (highBit << 1) | lowBit;
							
							if(patternValue & 0x3 == 0) {
								patternValue = 0;
							}
							
							let paletteIndex = Int(self.ppuMemory.readMemory(0x3F00 + patternValue));
							
							var pixelXCoord = self.cycle - 8 + k - Int(self.fineXScroll);
							
							// TODO: Wraps around from other side of screen, which is not the desired action
							// TODO: Add loading of the final column of tiles, to prevent this glitch
							if(pixelXCoord < 0) {
								pixelXCoord += 256;
							}
							
							var color = colors[paletteIndex];
							color.colorIndex = UInt8(patternValue);
							
							self.frame[self.scanline * 256 + pixelXCoord] = color;
						}
						
						incrementX();
					}
				}
			} else if(self.cycle <= 320) {
				if(self.cycle == 257) {
					self.secondaryOAMIndex = 0;
				}
				
				if(phaseIndex == 0 && self.secondaryOAMIndex < 32) {
					let yCoord = self.secondaryOAM[secondaryOAMIndex];
					var tileNumber = self.secondaryOAM[secondaryOAMIndex + 1];
					var attributes = self.secondaryOAM[secondaryOAMIndex + 2];
					let xCoord = self.secondaryOAM[secondaryOAMIndex + 3];
					
					var yShift = self.scanline - Int(yCoord);
					
					var basePatternTableAddress = 0x0000;
					
					let verticalFlip = getBit(7, pointer: &attributes);
					
					if(getBit(5, pointer: &self.PPUCTRL)) {
						// 8x16
						if(tileNumber & 0x1 == 1) {
							basePatternTableAddress = 0x1000;
							tileNumber = tileNumber - 1;
						}
						
						if(yShift > 7) {
							// Flip sprite vertically
							if(verticalFlip) {
								yShift = 15 - yShift;
							} else {
								tileNumber += 1;
								yShift -= 8;
							}
							
						} else if(verticalFlip) {
							tileNumber += 1;
							yShift = 7 - yShift;
						}
					} else {
						// 8x8
						if(getBit(3, pointer: &self.PPUCTRL)) {
							basePatternTableAddress = 0x1000;
						}
						
						// Flip sprite vertically
						if(verticalFlip) {
							yShift = 7 - yShift;
						}
					}
					
					var patternTableLow = self.ppuMemory.readMemory(basePatternTableAddress + (Int(tileNumber) << 4) + yShift);
					var patternTableHigh = self.ppuMemory.readMemory(basePatternTableAddress + (Int(tileNumber) << 4) + yShift + 8);
					
					// Flip sprite horizontally
					if(getBit(6, pointer: &attributes)) {
						patternTableLow = reverseByte(patternTableLow);
						patternTableHigh = reverseByte(patternTableHigh);
					}
					
					currentSpriteData[self.secondaryOAMIndex / 4] = Sprite(patternTableLow: patternTableLow, patternTableHigh: patternTableHigh, attribute: attributes, xCoord: xCoord, yCoord: yCoord);
					
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
	
	func incrementY() {
		// If fine Y < 7
		if((self.currentVramAddress & 0x7000) != 0x7000) {
			// Increment fine Y
			self.currentVramAddress = UInt16((Int(self.currentVramAddress) + 0x1000) & 0xFFFF);
		} else {
			// Fine Y = 0
			self.currentVramAddress &= 0x8FFF;
			// var y = coarse Y
			var y = (self.currentVramAddress & 0x03E0) >> 5;
			if(y == 29) {
				// Coarse Y = 0
				y = 0;
				// Switch vertical nametable
				self.currentVramAddress ^= 0x0800;
			} else if(y == 31) {
				// Coarse Y = 0, nametable not switched
				y = 0;
			} else {
				// Increment coarse Y
				y += 1;
			}
			
			// Put coarse Y back into v
			self.currentVramAddress = (self.currentVramAddress & 0xFC1F) | (y << 5);
		}

	}
	
	func incrementX() {
		// If coarse X == 31
		if((self.currentVramAddress & 0x001F) == 31) {
			// Coarse X = 0
			self.currentVramAddress &= 0xFFE0;
			
			// Switch horizontal nametable
			self.currentVramAddress ^= 0x0400;
		} else {
			// Increment coarse X
			self.currentVramAddress += 1;
		}
	}
	
	func copyY() {
		self.currentVramAddress = (self.currentVramAddress & 0x841F) | (self.tempVramAddress & 0x7BE0);
	}
	
	func copyX() {
		self.currentVramAddress = (self.currentVramAddress & 0xFBE0) | (self.tempVramAddress & 0x041F);
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
	
	func cpuWrite(index: Int, data: UInt8) {
		switch (index) {
			case 0:
				self.PPUCTRL = data;
				self.lastWrittenRegisterValue = data;
			case 1:
				self.PPUMASK = data;
				self.lastWrittenRegisterValue = data;
			case 2:
				//self.PPUSTATUS = data;
				break;
			case 3:
				self.OAMADDR = data;
				self.lastWrittenRegisterValue = data;
			case 4:
				self.OAMDATA = data;
			case 5:
				self.PPUSCROLL = data;
			case 6:
				self.PPUADDR = data;
				self.lastWrittenRegisterValue = data;
			case 7:
				self.PPUDATA = data;
			default:
				print("ERROR: Invalid CPU write index");
		}
	}
	
	func readPPUSTATUS() -> UInt8 {
		let temp = self.PPUSTATUS;
		
		// Clear VBlank flag
		setBit(7, value: false, pointer: &self.PPUSTATUS);
		
		self.writeToggle = false;
		
		return temp;
	}
	
	func readWriteOnlyRegister() -> UInt8 {
		// Reading any write only register should return last written value to a PPU register
		return self.lastWrittenRegisterValue;
	}
	
	func readPPUDATA() -> UInt8 {
		var value = self.ppuMemory.readMemory(Int(self.currentVramAddress));

		if (self.currentVramAddress % 0x4000 < 0x3F00) {
			let buffered = self.ppuDataReadBuffer;
			self.ppuDataReadBuffer = value;
			value = buffered;
		} else {
			self.ppuDataReadBuffer = self.ppuMemory.readMemory(Int(self.currentVramAddress) - 0x1000);
		}
		
		if(getBit(2, pointer: &self.PPUCTRL)) {
			self.currentVramAddress += 32;
		} else {
			self.currentVramAddress += 1;
		}
		
		return value
	}
	
	func dmaCopy() {
		let address = Int((UInt16(self.OAMDMA) << 8) & 0xFF00);
		
		for i in 0 ..< 256 {
			self.oamMemory.writeMemory(Int((UInt16(self.OAMADDR) + UInt16(i)) & 0xFF), data: self.cpuMemory.readMemory(address + i));
		}
		
		self.cpu!.startOAMTransfer();
	}
}