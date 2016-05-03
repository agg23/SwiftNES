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

struct Tile {
	var nameTable: UInt8;
	var attributeTable: UInt8;
	var patternTableLow: UInt8;
	var patternTableHigh: UInt8;
	var vramAddress: UInt16;
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
			self.vramIncrement = (PPUCTRL & 0x4) == 0x4;
			self.spritePatternTableAddress = (PPUCTRL & 0x8) == 0x8;
			self.backgroundPatternTableAddress = (PPUCTRL & 0x10) == 0x10;
			self.spriteSize = (PPUCTRL & 0x20) == 0x20;
			self.ppuMasterSlave = (PPUCTRL & 0x40) == 0x40;
			self.generateNMI = (PPUCTRL & 0x80) == 0x80;
			
			// Update tempVramAddress
			self.tempVramAddress = (self.tempVramAddress & 0xF3FF) | ((UInt16(PPUCTRL) & 0x03) << 10);
			
			nmiChange();
		}
	}
	
	/**
	 PPU Mask Register
	*/
	var PPUMASK: UInt8 {
		didSet {
			self.greyscale = (PPUMASK & 0x1) == 0x1;
			self.backgroundClipping = (PPUMASK & 0x2) == 0x2;
			self.spriteClipping = (PPUMASK & 0x4) == 0x4;
			self.renderBackground = (PPUMASK & 0x8) == 0x8;
			self.renderSprites = (PPUMASK & 0x10) == 0x10;
			self.emphasizeRed = (PPUMASK & 0x20) == 0x20;
			self.emphasizeGreen = (PPUMASK & 0x40) == 0x40;
			self.emphasizeBlue = (PPUMASK & 0x80) == 0x80;
			
			self.shouldRender = (self.renderBackground || self.renderSprites);
		}
	}

	/**
	 PPU Status Register
	*/
	var PPUSTATUS: UInt8;
	
	/**
	 OAM Address Port
	*/
	var OAMADDR: UInt8;

	/**
	 OAM Data Port
	*/
	var OAMDATA: UInt8 {
		didSet {
			var value = OAMDATA;
			
			if((self.renderBackground || self.renderSprites) && self.scanline > 239) {
				value = 0xFF;
			}
			
			if(self.OAMADDR % 4 == 2) {
				value = value & 0xE3;
			}
			
			self.oamMemory.writeMemory(Int(self.OAMADDR), data: value);
			
			self.OAMADDR = UInt8((Int(self.OAMADDR) + 1) & 0xFF);
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
				// TODO: Fix hack
				self.currentPPUADDRAddress = self.tempVramAddress;
			} else {
				self.tempVramAddress = (self.tempVramAddress & 0x80FF) | ((UInt16(PPUADDR) & 0x3F) << 8);
			}
			
			self.writeToggle = !self.writeToggle;
		}
	}
	
	/**
	 PPU Data Port
	*/
	var PPUDATA: UInt8 {
		didSet {
			self.ppuMemory.writeMemory(Int(self.currentPPUADDRAddress), data: PPUDATA);
			
			// Increment VRAM address
			if(self.vramIncrement) {
				self.currentVramAddress += 32;
				self.currentPPUADDRAddress += 32;
			} else {
				self.currentVramAddress += 1;
				self.currentPPUADDRAddress += 1;
			}
			
			self.currentVramAddress = self.currentVramAddress & 0x7FFF;
		}
	}
	
	/*
	 OAM DMA Register
	*/
	var OAMDMA: UInt8 {
		didSet {
			self.cpu!.startOAMTransfer();
		}
	}
	
	// MARK: - Register Bits
	
	/*
		PPUCTRL Bits
	*/
	private var vramIncrement: Bool;
	private var spritePatternTableAddress: Bool;
	private var backgroundPatternTableAddress: Bool;
	private var spriteSize: Bool;
	private var ppuMasterSlave: Bool;
	private var generateNMI: Bool;
	
	/*
		PPUMASK Bits
	*/
	private var greyscale: Bool;
	private var backgroundClipping: Bool;
	private var spriteClipping: Bool;
	private var renderBackground: Bool;
	private var renderSprites: Bool;
	private var emphasizeRed: Bool;
	private var emphasizeGreen: Bool;
	private var emphasizeBlue: Bool;
	
	/*
		PPUSTATUS Bits
	*/
	private var spriteOverflow: Bool;
	private var sprite0Hit: Bool;
	private var vblank: Bool;
	
	// MARK: - Other Variables
	
	private var shouldRender: Bool;
	
	/**
	 Used to indicate whether OAMDATA needs to be written
	*/
	private var writeOAMDATA: Bool;
	
	/**
	 Stores the current scanline of the PPU
	*/
	var scanline: Int;
	
	/**
	 Stores the current pixel of the PPU
	*/
	private var pixelIndex: Int;
	
	/**
	 Stores the current frame data to be drawn to the screen
	*/
	var frame: [RGB];
	
	var cycle: Int;
	
	var frameReady = false;
	
	private var initFrame = true;
	
	private var evenFrame = false;
	
	private var nmiPrevious = false;
	private var nmiDelay: Int = 0;
	
	private var suppressNMI = false;
	private var suppressVBlankFlag = false;
	
	private var cyclesSinceNMI = -1;
		
	var cpu: CPU?;
	private let cpuMemory: Memory;
	private let ppuMemory: Memory;
	let oamMemory: Memory;
	
	private var secondaryOAM = [UInt8](count: 32, repeatedValue: 0);
	private var spriteZeroWillBeInSecondaryOAM = false;
	private var spriteZeroInSecondaryOAM = false;
	
	/**
	 Buffers PPUDATA reads
	*/
	private var ppuDataReadBuffer: UInt8;
	
	/**
	 Any write to a PPU register will set this value
	*/
	private var lastWrittenRegisterValue: UInt8;
	private var lastWrittenRegisterDecayed = true;
	private var lastWrittenRegisterSetCycle: Int;
	
	private var currentVramAddress: UInt16;
	private var tempVramAddress: UInt16;
	private var fineXScroll: UInt8;
	private var writeToggle: Bool;
	
	private var currentPPUADDRAddress: UInt16;
	
	
	// MARK: Stored Values Between Cycles -
	private var nameTable: UInt8;
	private var attributeTable: UInt8;
	private var patternTableLow: UInt8;
	private var patternTableHigh: UInt8;
	
	private var currentTileData = [Tile](count: 34, repeatedValue: Tile(nameTable: 0, attributeTable: 0, patternTableLow: 0, patternTableHigh: 0, vramAddress: 0));
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
		
		self.currentPPUADDRAddress = 0;
		
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
		
		self.vramIncrement = false;
		self.spritePatternTableAddress = false;
		self.backgroundPatternTableAddress = false;
		self.spriteSize = false;
		self.ppuMasterSlave = false;
		self.generateNMI = false;
		
		self.greyscale = false;
		self.backgroundClipping = false;
		self.spriteClipping = false;
		self.renderBackground = false;
		self.renderSprites = false;
		self.emphasizeRed = false;
		self.emphasizeGreen = false;
		self.emphasizeBlue = false;
		
		self.spriteOverflow = false;
		self.sprite0Hit = false;
		self.vblank = false;
		
		self.shouldRender = false;
		
		self.scanline = 241;
		self.pixelIndex = 0;
		
		self.cycle = 0;
		
		self.ppuDataReadBuffer = 0;
		self.lastWrittenRegisterValue = 0;
		
		self.lastWrittenRegisterSetCycle = 0;
		
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
	
	final func setVBlank() {
		if(!self.suppressVBlankFlag) {
			self.vblank = true;
		}

		self.suppressVBlankFlag = false;
		
		nmiChange();
	}
	
	final func clearVBlank() {
		self.vblank = false;
		nmiChange();
	}
	
	final func nmiChange() {
		let nmi = self.generateNMI && self.vblank;
		
		if(nmi && !self.nmiPrevious) {
			if(self.scanline != 241 || self.cycle != 1) {
				// Delay interrupt by one instruction
				self.cpu!.interruptDelay = true;
			}

			self.nmiDelay = 2;
		}
		
		self.nmiPrevious = nmi;
	}
	
	final func step() {
		if(self.nmiDelay > 0) {
			self.nmiDelay -= 1;
			if(self.nmiDelay == 0 && self.generateNMI && self.vblank) {
				self.cpu!.queueInterrupt(CPU.Interrupt.VBlank);
				self.cyclesSinceNMI = 0;
			}
		}
		
		if(self.cyclesSinceNMI > 0) {
			self.cyclesSinceNMI += 1;
			
			if(self.cyclesSinceNMI > 3) {
				self.cyclesSinceNMI = -1;
			}
		}
		
		if(self.cycle > 256 && self.scanline < 240) {
			self.OAMADDR = 0;
		}
		
		if(self.cycle == 256 && self.shouldRender) {
			incrementY();
		} else if(self.cycle == 257 && self.shouldRender) {
			copyX();
		}
		
		if(self.cycle == 0) {
			self.OAMADDR = 0;
		}
		
		if(self.scanline >= 240) {
			// VBlank period
			
			if(self.scanline == 241 && self.cycle == 1) {
				if(!self.initFrame) {
					setVBlank();
				} else {
					self.initFrame = false;
				}
			}
			
			// TODO: Handle glitchy increment on non-VBlank scanlines as referenced:
			// http://wiki.nesdev.com/w/index.php/PPU_registers
//			if(self.writeOAMDATA && self.scanline != 240) {
//				self.writeOAMDATA = false;
//				
//				self.oamMemory.writeMemory(Int(self.OAMADDR), data: self.OAMDATA);
//				
//				if(getBit(2, pointer: &self.PPUCTRL)) {
//					self.OAMADDR = UInt8((Int(self.OAMADDR) + 32) & 0xFF);
//				} else {
//					self.OAMADDR = UInt8((Int(self.OAMADDR) + 1) & 0xFF);
//				}
//			}
		} else if(self.scanline == -1) {
			// TODO: Update horizontal and vertical scroll counters
			
			if(self.cycle == 1) {
				// Clear sprite overflow flag
				self.spriteOverflow = false;
				
				// Clear sprite 0 hit flag
				self.sprite0Hit = false;
				
				// Clear VBlank flag
				clearVBlank();
			} else if(!self.evenFrame && self.cycle == 338 && self.shouldRender) {
				// Skip tick on odd frame
				self.cycle = 340;
				
				return;
			}
			
			if(self.cycle == 304 && self.shouldRender) {
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
					self.spriteZeroWillBeInSecondaryOAM = false;
				} else {
					if(self.oamStage == 0) {
						if(self.cycle % 2 == 0 && self.scanline != 239) {
							
							let intOAMByte = Int(self.oamByte);
							let intScanline = Int(self.scanline);
							
							var spriteHeight = 8;
							
							if(self.spriteSize) {
								spriteHeight = 16;
							}
							
							if(intOAMByte < 240 && intOAMByte <= intScanline && intOAMByte + spriteHeight > intScanline) {
								
								if(self.secondaryOAMIndex >= 32) {
									if(self.renderSprites) {
										// TODO: Handle overflow
										self.spriteOverflow = true;
									}
								} else {
									
									// Sprite should be drawn on this line
									self.secondaryOAM[self.secondaryOAMIndex] = self.oamByte;
									self.secondaryOAM[self.secondaryOAMIndex + 1] = self.oamMemory.readMemory(4 * self.oamIndex + 1);
									self.secondaryOAM[self.secondaryOAMIndex + 2] = self.oamMemory.readMemory(4 * self.oamIndex + 2);
									self.secondaryOAM[self.secondaryOAMIndex + 3] = self.oamMemory.readMemory(4 * self.oamIndex + 3);
									
									if(self.oamIndex == 0) {
										self.spriteZeroWillBeInSecondaryOAM = true;
									}
									
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
				
				if(self.renderBackground) {
					// If rendering cycle and rendering background bit is set
					let xCoord = (self.cycle - 1 + Int(self.fineXScroll));
					
					let tile = self.currentTileData[xCoord / 8];
					
					renderBackgroundPixel(tile, tileXCoord: (xCoord / 8) * 8, pixelOffset: xCoord % 8);
					
					if(phaseIndex == 2) {
						// Fetch Name Table
						fetchNameTable();
					} else if(phaseIndex == 4) {
						fetchAttributeTable();
					} else if(phaseIndex == 6) {
						fetchLowPatternTable();
					} else if(phaseIndex == 0) {
						fetchHighPatternTable();
						
						self.currentTileData[(self.cycle - 1) / 8 + 2] = Tile(nameTable: self.nameTable, attributeTable: self.attributeTable,
						                                                patternTableLow: self.patternTableLow, patternTableHigh: self.patternTableHigh,
						                                                vramAddress: self.currentVramAddress);
						
						incrementX();
					}
				}
				
				if(self.renderSprites) {
					renderSpritePixel(self.cycle - 1);
				}
			} else if(self.cycle <= 320) {
				if(self.cycle == 257) {
					self.secondaryOAMIndex = 0;
				}
				
				self.spriteZeroInSecondaryOAM = self.spriteZeroWillBeInSecondaryOAM;
				
				if(phaseIndex == 0 && self.secondaryOAMIndex < 32) {
					let yCoord = self.secondaryOAM[secondaryOAMIndex];
					var tileNumber = self.secondaryOAM[secondaryOAMIndex + 1];
					var attributes = self.secondaryOAM[secondaryOAMIndex + 2];
					let xCoord = self.secondaryOAM[secondaryOAMIndex + 3];
					
					var yShift = self.scanline - Int(yCoord);
					
					var basePatternTableAddress = 0x0000;
					
					let verticalFlip = getBit(7, pointer: &attributes);
					
					if(self.spriteSize) {
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
						if(self.spritePatternTableAddress) {
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
				if(phaseIndex == 2) {
					// Fetch Name Table
					fetchNameTable();
				} else if(phaseIndex == 4) {
					fetchAttributeTable();
				} else if(phaseIndex == 6) {
					fetchLowPatternTable();
				} else if(phaseIndex == 0) {
					fetchHighPatternTable();
					
					let tile = Tile(nameTable: self.nameTable, attributeTable: self.attributeTable, patternTableLow: self.patternTableLow,
					                patternTableHigh: self.patternTableHigh, vramAddress: self.currentVramAddress);
					
					if(self.cycle == 328) {
						self.currentTileData[0] = tile;
					} else {
						self.currentTileData[1] = tile;
					}
					
					incrementX();
				}
			} else {
				// TODO: Fetch garbage Name Table byte
			}
		}
		
		self.cycle += 1;
		
		if(!self.lastWrittenRegisterDecayed) {
			self.lastWrittenRegisterSetCycle += 1;
			
			if(self.lastWrittenRegisterSetCycle > 5369318) {
				self.lastWrittenRegisterDecayed = true;
				self.lastWrittenRegisterSetCycle = 0;
				self.lastWrittenRegisterValue = 0;
			}
		}
		
		if(self.cycle == 341) {
			self.cycle = 0;
			if(self.scanline == 260) {
				// Frame completed
				self.scanline = -1;
				
				self.evenFrame = !self.evenFrame;
				
				self.frameReady = true;
				
				return;
			} else {
				scanline += 1;
			}
		}
		
		return;
	}
	
	final func renderSpritePixel(currentXCoord: Int) {
		for i in 0 ..< 8 {
			var sprite = currentSpriteData[i];
			let xCoord = Int(sprite.xCoord);
			
			let xOffset = currentXCoord - xCoord;
			
			if(xOffset < 0 || xOffset > 7 || xCoord >= 0xFF) {
				continue;
			}
			
			let lowBit = getBit(7 - xOffset, pointer: &sprite.patternTableLow) ? 1 : 0;
			let highBit = getBit(7 - xOffset, pointer: &sprite.patternTableHigh) ? 1 : 0;
			
			let attributeBits = Int(sprite.attribute) & 0x3;
			
			let patternValue = (attributeBits << 2) | (highBit << 1) | lowBit;
			
			let paletteIndex = Int(self.ppuMemory.readMemory(0x3F10 + patternValue));
			
			// First color each section of sprite palette is transparent
			if(patternValue & 0x3 == 0) {
				continue;
			}
			
			// TODO: X coordinate of sprites is off slightly
			
			let address = self.scanline * 256 + xCoord + xOffset;
			
			if(address >= 256 * 240) {
				// TODO: Fix
				continue;
			}
			
			let backgroundPixel = self.frame[address];
			
			let backgroundTransparent = backgroundPixel.colorIndex & 0x3 == 0;
			
			if(self.spriteZeroInSecondaryOAM && i == 0 && self.renderBackground && !backgroundTransparent) {
				// Sprite 0 and Background is not transparent
				
				
				// If bits 1 or 2 in PPUMASK are clear and the x coordinate is between 0 and 7, don't hit
				// If x coordinate is 255 or greater, don't hit
				// If y coordinate is 239 or greater, don't hit
				if(!((!self.backgroundClipping || !self.spriteClipping) && xCoord + xOffset < 8)
					&& xCoord + xOffset < 255
					&& sprite.yCoord < 239) {
					self.sprite0Hit = true;
					self.spriteZeroInSecondaryOAM = false;
				}
			}
			
			if(!getBit(5, pointer: &sprite.attribute) || backgroundTransparent) {
				self.frame[address] = colors[paletteIndex];
				return;
			}
		}
	}
	
	final func renderBackgroundPixel(tile: Tile, tileXCoord: Int, pixelOffset: Int) {
		// Draw pixels from tile
		var patternTableLow = tile.patternTableLow;
		var patternTableHigh = tile.patternTableHigh;
		
		if(tileXCoord == 0 && pixelOffset == 0) {
		
		}
		
		var pixelXCoord = tileXCoord + pixelOffset - Int(self.fineXScroll);
		
		let lowBit = getBit(7 - pixelOffset, pointer: &patternTableLow) ? 1 : 0;
		let highBit = getBit(7 - pixelOffset, pointer: &patternTableHigh) ? 1 : 0;
		
		let attributeShift = Int(((tile.vramAddress >> 4) & 4) | (tile.vramAddress & 2));
		
		let attributeBits = (Int(tile.attributeTable) >> attributeShift) & 0x3;
		
		var patternValue = (attributeBits << 2) | (highBit << 1) | lowBit;
		
		if(patternValue & 0x3 == 0) {
			patternValue = 0;
		}
		
		let paletteIndex = Int(self.ppuMemory.readMemory(0x3F00 + patternValue));
		
		if(pixelXCoord < 0) {
			pixelXCoord += 256;
		}
		
		var color = colors[paletteIndex];
		color.colorIndex = UInt8(patternValue);
		
		self.frame[self.scanline * 256 + pixelXCoord] = color;
	}
	
	final func fetchNameTable() {
		// Fetch Name Table
		self.nameTable = self.ppuMemory.readMemory(0x2000 | (Int(self.currentVramAddress) & 0x0FFF));
	}
	
	final func fetchAttributeTable() {
		// Fetch Attribute Table
		let currentVramAddress = Int(self.currentVramAddress);
		self.attributeTable = self.ppuMemory.readMemory(0x23C0 | (currentVramAddress & 0x0C00) | ((currentVramAddress >> 4) & 0x38) | ((currentVramAddress >> 2) & 0x07));
	}
	
	final func fetchLowPatternTable() {
		// Fetch lower Pattern Table byte
		var basePatternTableAddress = 0x0000;
		
		if(self.backgroundPatternTableAddress) {
			basePatternTableAddress = 0x1000;
		}
		
		let fineY = (Int(self.currentVramAddress) >> 12) & 7;
		
		self.patternTableLow = self.ppuMemory.readMemory(basePatternTableAddress + (Int(self.nameTable) << 4) + fineY);
	}
	
	final func fetchHighPatternTable() {
		// Fetch upper Pattern Table byte
		var basePatternTableAddress = 0x0008;
		
		if(self.backgroundPatternTableAddress) {
			basePatternTableAddress = 0x1008;
		}
		
		let fineY = (Int(self.currentVramAddress) >> 12) & 7;
		
		self.patternTableHigh = self.ppuMemory.readMemory(basePatternTableAddress + (Int(self.nameTable) << 4) + fineY);
	}
	
	final func incrementY() {
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
	
	final func incrementX() {
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
	
	final func copyY() {
		self.currentVramAddress = (self.currentVramAddress & 0x841F) | (self.tempVramAddress & 0x7BE0);
	}
	
	final func copyX() {
		self.currentVramAddress = (self.currentVramAddress & 0xFBE0) | (self.tempVramAddress & 0x041F);
	}
	
	// MARK - Registers
	
	final func setBit(index: Int, value: Bool, pointer: UnsafeMutablePointer<UInt8>) {
		let bit: UInt8 = value ? 0xFF : 0;
		pointer.memory ^= (bit ^ pointer.memory) & (1 << UInt8(index));
	}
	
	final func getBit(index: Int, pointer: UnsafePointer<UInt8>) -> Bool {
		return ((pointer.memory >> UInt8(index)) & 0x1) == 1;
	}
	
	/**
	 Bit level reverses the given byte
	 From http://stackoverflow.com/a/2602885
	*/
	final func reverseByte(value: UInt8) -> UInt8 {
		var b = (value & 0xF0) >> 4 | (value & 0x0F) << 4;
		b = (b & 0xCC) >> 2 | (b & 0x33) << 2;
		b = (b & 0xAA) >> 1 | (b & 0x55) << 1;
		return b;
	}
	
	final func cpuWrite(index: Int, data: UInt8) {
		switch (index) {
			case 0:
				self.PPUCTRL = data;
			case 1:
				self.PPUMASK = data;
			case 2:
				break;
			case 3:
				self.OAMADDR = data;
			case 4:
				self.OAMDATA = data;
			case 5:
				self.PPUSCROLL = data;
			case 6:
				self.PPUADDR = data;
			case 7:
				self.PPUDATA = data;
			default:
				print("ERROR: Invalid CPU write index");
		}
		
		// Update decay register
		self.lastWrittenRegisterValue = data;
		self.lastWrittenRegisterDecayed = false;
		self.lastWrittenRegisterSetCycle = 0;
	}
	
	final func readPPUSTATUS() -> UInt8 {
		var temp = (self.lastWrittenRegisterValue & 0x1F);
		
		temp |= self.spriteOverflow ? 0x20 : 0;
		temp |= self.sprite0Hit ? 0x40: 0;
		temp |= self.vblank ? 0x80: 0;
		
		// Clear VBlank flag
		self.vblank = false;
		
		self.writeToggle = false;
		
		nmiChange();
		
		if(self.scanline == 241) {
			if(self.cycle == 1) {
				self.suppressVBlankFlag = true;
			} else if(self.cycle == 2 && self.cyclesSinceNMI != -1) {
				self.cpu?.queueInterrupt(nil);
			}
		}
		
		return temp;
	}
	
	final func readWriteOnlyRegister() -> UInt8 {
		// Reading any write only register should return last written value to a PPU register
		return self.lastWrittenRegisterValue;
	}
	
	final func readOAMDATA() -> UInt8 {
		var value = self.oamMemory.readMemory(Int(self.OAMADDR));
		
		if(self.OAMADDR % 4 == 2) {
			value = value & 0xE3;
			
			self.lastWrittenRegisterValue = value;
			self.lastWrittenRegisterDecayed = false;
			self.lastWrittenRegisterSetCycle = 0;
		}
		
		return value;
	}
	
	final func readPPUDATA() -> UInt8 {
		// TODO: Switch back to currentVramAddress
		var value = self.ppuMemory.readMemory(Int(self.currentPPUADDRAddress));
		
		if (self.currentPPUADDRAddress % 0x4000 < 0x3F00) {
			let buffered = self.ppuDataReadBuffer;
			self.ppuDataReadBuffer = value;
			value = buffered;
		} else {
			self.ppuDataReadBuffer = self.ppuMemory.readMemory(Int(self.currentPPUADDRAddress) - 0x1000);
//			value = (self.ppuDataReadBuffer & 0x3F) | (self.lastWrittenRegisterValue & 0xC0);
		}
		
		if(self.vramIncrement) {
			self.currentPPUADDRAddress += 32;
		} else {
			self.currentPPUADDRAddress += 1;
		}
		
		// Update decay register
		self.lastWrittenRegisterValue = value;
		self.lastWrittenRegisterDecayed = false;
		
		return value;
	}
	
	final func dumpMemory() {
		self.ppuMemory.dumpMemory();
	}
}