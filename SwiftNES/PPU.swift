//
//  PPU.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 4/2/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

struct Sprite {
	var patternTableLow: UInt8
	var patternTableHigh: UInt8
	var attribute: UInt8
	var xCoord: UInt8
	var yCoord: UInt8
}

struct Tile {
	var nameTable: UInt8
	var attributeTable: UInt8
	var patternTableLow: UInt8
	var patternTableHigh: UInt8
	var vramAddress: UInt16
}

private let colors: [UInt32] = [0x7C7C7C, 0x0000FC, 0x0000BC, 0x4428BC, 0x940084, 0xA80020, 0xA81000,
				0x881400, 0x503000, 0x007800, 0x006800, 0x005800, 0x004058, 0x000000,
				0x000000, 0x000000, 0xBCBCBC, 0x0078F8, 0x0058F8, 0x6844FC, 0xD800CC,
				0xE40058, 0xF83800, 0xE45C10, 0xAC7C00, 0x00B800, 0x00A800, 0x00A844,
				0x008888, 0x000000, 0x000000, 0x000000, 0xF8F8F8, 0x3CBCFC, 0x6888FC,
				0x9878F8, 0xF878F8, 0xF85898, 0xF87858, 0xFCA044, 0xF8B800, 0xB8F818,
				0x58D854, 0x58F898, 0x00E8D8, 0x787878, 0x000000, 0x000000, 0xFCFCFC,
				0xA4E4FC, 0xB8B8F8, 0xD8B8F8, 0xF8B8F8, 0xF8A4C0, 0xF0D0B0, 0xFCE0A8,
				0xF8D878, 0xD8F878, 0xB8F8B8, 0xB8F8D8, 0x00FCFC, 0xF8D8F8, 0x000000,
				0x000000]

final class PPU: NSObject {
	/**
	 PPU Control Register
	*/
	var PPUCTRL: UInt8 {
		didSet {
			vramIncrement = (PPUCTRL & 0x4) == 0x4
			spritePatternTableAddress = (PPUCTRL & 0x8) == 0x8
			backgroundPatternTableAddress = (PPUCTRL & 0x10) == 0x10
			spriteSize = (PPUCTRL & 0x20) == 0x20
			ppuMasterSlave = (PPUCTRL & 0x40) == 0x40
			generateNMI = (PPUCTRL & 0x80) == 0x80
			
			// Update tempVramAddress
			tempVramAddress = (tempVramAddress & 0xF3FF) | ((UInt16(PPUCTRL) & 0x03) << 10)
			
			nmiChange()
		}
	}
	
	/**
	 PPU Mask Register
	*/
	var PPUMASK: UInt8 {
		didSet {
			greyscale = (PPUMASK & 0x1) == 0x1
			backgroundClipping = (PPUMASK & 0x2) == 0x2
			spriteClipping = (PPUMASK & 0x4) == 0x4
			renderBackground = (PPUMASK & 0x8) == 0x8
			renderSprites = (PPUMASK & 0x10) == 0x10
			emphasizeRed = (PPUMASK & 0x20) == 0x20
			emphasizeGreen = (PPUMASK & 0x40) == 0x40
			emphasizeBlue = (PPUMASK & 0x80) == 0x80
			
			shouldRender = (renderBackground || renderSprites)
		}
	}

	/**
	 PPU Status Register
	*/
	var PPUSTATUS: UInt8
	
	/**
	 OAM Address Port
	*/
	var OAMADDR: UInt8

	/**
	 OAM Data Port
	*/
	var OAMDATA: UInt8 {
		didSet {
			var value = OAMDATA
			
			if (renderBackground || renderSprites) && scanline > 239 {
				value = 0xFF
			}
			
			if OAMADDR % 4 == 2 {
				value = value & 0xE3
			}
			
//			self.oamMemory.writeMemory(Int(self.OAMADDR), data: value)
			oamMemory[Int(OAMADDR)] = value
			
			OAMADDR = UInt8((Int(OAMADDR) + 1) & 0xFF)
		}
	}
	
	/**
	 PPU Scrolling Position Register
	*/
	var PPUSCROLL: UInt8 {
		didSet {
			if writeToggle {
				// Second write
				tempVramAddress = (tempVramAddress & 0x8FFF) | ((UInt16(PPUSCROLL) & 0x7) << 12)
				tempVramAddress = (tempVramAddress & 0xFC1F) | ((UInt16(PPUSCROLL) & 0xF8) << 2)
			} else {
				tempVramAddress = (tempVramAddress & 0xFFE0) | (UInt16(PPUSCROLL) >> 3)
				fineXScroll = PPUSCROLL & 0x7
			}
			
			writeToggle = !writeToggle
		}
	}
	
	/**
	 PPU Address Register
	*/
	var PPUADDR: UInt8 {
		didSet {
			if writeToggle {
				// Second write
				tempVramAddress = (tempVramAddress & 0xFF00) | UInt16(PPUADDR)
				currentVramAddress = tempVramAddress
				
				a12(tempVramAddress, old: currentPPUADDRAddress)

				// TODO: Fix hack
				currentPPUADDRAddress = tempVramAddress
			} else {
				tempVramAddress = (tempVramAddress & 0x80FF) | ((UInt16(PPUADDR) & 0x3F) << 8)
			}
			
			writeToggle = !writeToggle
		}
	}
	
	/**
	 PPU Data Port
	*/
	var PPUDATA: UInt8 {
		didSet {
			ppuMemory.writeMemory(Int(currentPPUADDRAddress), data: PPUDATA)
			
			let temp = currentPPUADDRAddress
			
			// Increment VRAM address
			if vramIncrement {
				currentVramAddress += 32
				currentPPUADDRAddress += 32
			} else {
				currentVramAddress += 1
				currentPPUADDRAddress += 1
			}
			
			a12(currentPPUADDRAddress, old: temp)
			
			currentVramAddress = currentVramAddress & 0x7FFF
		}
	}
	
	/*
	 OAM DMA Register
	*/
	var OAMDMA: UInt8 {
		didSet {
			cpu.startOAMTransfer()
		}
	}
	
	// MARK: - Register Bits
	
	/*
		PPUCTRL Bits
	*/
	private var vramIncrement: Bool
	private var spritePatternTableAddress: Bool
	private var backgroundPatternTableAddress: Bool
	private var spriteSize: Bool
	private var ppuMasterSlave: Bool
	private var generateNMI: Bool
	
	/*
		PPUMASK Bits
	*/
	private var greyscale: Bool
	private var backgroundClipping: Bool
	private var spriteClipping: Bool
	private var renderBackground: Bool
	private var renderSprites: Bool
	private var emphasizeRed: Bool
	private var emphasizeGreen: Bool
	private var emphasizeBlue: Bool
	
	/*
		PPUSTATUS Bits
	*/
	private var spriteOverflow: Bool
	private var sprite0Hit: Bool
	private var vblank: Bool
	
	// MARK: - Other Variables
	
	private var shouldRender: Bool
	
	/**
	 Used to indicate whether OAMDATA needs to be written
	*/
	private var writeOAMDATA: Bool
	
	/**
	 Stores the current scanline of the PPU
	*/
	private var scanline: Int
	
	/**
	 Stores the current pixel of the PPU
	*/
	private var pixelIndex: Int
	
	private var pixelSize: Int = 2
	private var totalPixelCount = 256 * 240 * 2 * 2
	
	/**
	 Stores the current frame data to be drawn to the screen
	*/
	var frame: [UInt32]
	
	private var cycle: Int
	
	var frameReady = false
	
	private var initFrame = true
	
	private var evenFrame = false
	
	private var nmiPrevious = false
	private var nmiDelay: Int = 0
	
	private var suppressNMI = false
	private var suppressVBlankFlag = false
	
	private var cyclesSinceNMI = -1
		
	var cpu: CPU!
	private let cpuMemory: CPUMemory
	private let ppuMemory: PPUMemory
	private var oamMemory: [UInt8]
	
	private var secondaryOAM = [UInt8](repeating: 0, count: 32)
	private var spriteZeroWillBeInSecondaryOAM = false
	private var spriteZeroInSecondaryOAM = false
	
	/**
	 Buffers PPUDATA reads
	*/
	private var ppuDataReadBuffer: UInt8
	
	/**
	 Any write to a PPU register will set this value
	*/
	private var lastWrittenRegisterValue: UInt8
	private var lastWrittenRegisterDecayed = true
	private var lastWrittenRegisterSetCycle: Int
	
	private var currentVramAddress: UInt16
	private var tempVramAddress: UInt16
	private var fineXScroll: UInt8
	private var writeToggle: Bool
	
	private var currentPPUADDRAddress: UInt16
	
	
	// MARK: Stored Values Between Cycles -
	private var nameTable: UInt8
	private var attributeTable: UInt8
	private var patternTableLow: UInt8
	private var patternTableHigh: UInt8
	
	private var currentTileData = [Tile](repeating: Tile(nameTable: 0, attributeTable: 0, patternTableLow: 0, patternTableHigh: 0, vramAddress: 0), count: 34)
	private var currentSpriteData = [Sprite](repeating: Sprite(patternTableLow: 0xFF, patternTableHigh: 0xFF, attribute: 0, xCoord: 0, yCoord: 0), count: 8)
	
	private var spriteYCoord: UInt8
	private var spriteTileNumber: UInt8
	private var spriteAttributes: UInt8
	private var spriteXCoord: UInt8
	private var spriteBaseAddress: Int
	private var spriteYShift: Int
	
	private var oamByte: UInt8
	
	private var oamStage = 0
	private var oamIndex = 0
	private var oamIndexOverflow = 0
	private var secondaryOAMIndex = 0
	
	// MARK: Methods -
	
	init(cpuMemory: CPUMemory, ppuMemory: PPUMemory) {
		cpu = nil
		
		self.cpuMemory = cpuMemory
		self.ppuMemory = ppuMemory
		oamMemory = [UInt8](repeating: 0, count: 0x100)
		
		writeOAMDATA = false
		
		currentVramAddress = 0
		tempVramAddress = 0
		fineXScroll = 0
		writeToggle = false
		
		currentPPUADDRAddress = 0
		
		PPUCTRL = 0
		PPUMASK = 0
		//self.PPUSTATUS = 0xA0
		PPUSTATUS = 0
		OAMADDR = 0
		OAMDATA = 0
		PPUSCROLL = 0
		PPUADDR = 0
		PPUDATA = 0
		OAMDMA = 0
		
		vramIncrement = false
		spritePatternTableAddress = false
		backgroundPatternTableAddress = false
		spriteSize = false
		ppuMasterSlave = false
		generateNMI = false
		
		greyscale = false
		backgroundClipping = false
		spriteClipping = false
		renderBackground = false
		renderSprites = false
		emphasizeRed = false
		emphasizeGreen = false
		emphasizeBlue = false
		
		spriteOverflow = false
		sprite0Hit = false
		vblank = false
		
		shouldRender = false
		
		scanline = 241
		pixelIndex = 0
		
		cycle = 0
		
		ppuDataReadBuffer = 0
		lastWrittenRegisterValue = 0
		
		lastWrittenRegisterSetCycle = 0
		
		nameTable = 0
		attributeTable = 0
		patternTableLow = 0
		patternTableHigh = 0
		
		spriteYCoord = 0
		spriteTileNumber = 0
		spriteAttributes = 0
		spriteXCoord = 0
		spriteBaseAddress = 0
		spriteYShift = 0
		
		oamByte = 0
		
		frame = [UInt32](repeating: 0, count: totalPixelCount)
	}
	
	func reset() {
		
	}
	
	func setVBlank() {
		if !suppressVBlankFlag {
			vblank = true
		}

		suppressVBlankFlag = false
		
		nmiChange()
	}
	
	func clearVBlank() {
		vblank = false
		nmiChange()
	}
	
	func nmiChange() {
		let nmi = generateNMI && vblank
		
		if nmi && !nmiPrevious {
			nmiDelay = 2
		}
		
		nmiPrevious = nmi
	}
	
	func step() {
		cycle += 1
		
		if cycle == 341 {
			cycle = 0
			
			if scanline == 260 {
				// Frame completed
				scanline = -1
				
				evenFrame = !evenFrame
				
				frameReady = true
			} else {
				scanline += 1
			}
		}
		
		if ppuMemory.a12Timer > 0 {
			ppuMemory.a12Timer -= 1
		}
		
		if nmiDelay > 0 {
			nmiDelay -= 1
			if nmiDelay == 0 && generateNMI && vblank {
				cpu.queueNMI()
				cyclesSinceNMI = 0
			}
		}
		
		if cyclesSinceNMI > 0 {
			cyclesSinceNMI += 1
			
			if cyclesSinceNMI > 3 {
				cyclesSinceNMI = -1
			}
		}
		
		if cycle == 0 {
			OAMADDR = 0
		} else if cycle == 256 && shouldRender {
			incrementY()
		} else if cycle == 257 && shouldRender {
			copyX()
			
			// Set in order to optimize the below else if
			OAMADDR = 0
		} else if cycle > 256 && scanline < 240 {
			OAMADDR = 0
		}
		
		if scanline >= 240 {
			// VBlank period
			
			if scanline == 241 && cycle == 1 {
				if !initFrame {
					setVBlank()
				} else {
					initFrame = false
				}
			}
			
			// TODO: Handle glitchy increment on non-VBlank scanlines as referenced:
			// http://wiki.nesdev.com/w/index.php/PPU_registers
		} else if scanline == -1 {
			if cycle == 1 {
				// Clear sprite overflow flag
				spriteOverflow = false
				
				// Clear sprite 0 hit flag
				sprite0Hit = false
				
				// Clear VBlank flag
				clearVBlank()
			} else if !evenFrame && cycle == 338 && shouldRender {
				// Skip tick on odd frame
				cycle = 339
				
				return
			} else if cycle > 256 {
				visibleScanlineTick()
			}
			
			if cycle == 304 && shouldRender {
				copyY()
			}
		} else {
			// Visible scanlines
			
			visibleScanlineTick()
		}
		
		if !lastWrittenRegisterDecayed {
			lastWrittenRegisterSetCycle += 1
			
			if lastWrittenRegisterSetCycle > 5369318 {
				lastWrittenRegisterDecayed = true
				lastWrittenRegisterSetCycle = 0
				lastWrittenRegisterValue = 0
			}
		}
		
	}
	
	func visibleScanlineTick() {
		let phaseIndex = self.cycle % 8
		
		if cycle == 0 {
			oamStage = 0
			oamIndex = 0
			oamIndexOverflow = 0
			secondaryOAMIndex = 0
			
			// Do nothing
		} else if cycle <= 256 {
			// Do sprite calculations whether or not draw sprite bit is set
			
			if cycle <= 64 {
				// Set secondary OAM to 0xFF
				if cycle % 2 == 0 {
					secondaryOAM[cycle / 2 - 1] = 0xFF
				}
				spriteZeroWillBeInSecondaryOAM = false
			} else {
				if oamStage == 0 {
					fetchSprite()
				}
			}
			
			let backgroundPixelIsTransparent: Bool
			
			if renderBackground {
				// If rendering cycle and rendering background bit is set
				let xCoord = (cycle - 1 + Int(fineXScroll))
				
				let tile = currentTileData[xCoord / 8]
				
				backgroundPixelIsTransparent = renderBackgroundPixel(tile, tileXCoord: (xCoord / 8) * 8, pixelOffset: xCoord % 8)
				
				if phaseIndex == 2 {
					// Fetch Name Table
					fetchNameTable()
				} else if phaseIndex == 4 {
					fetchAttributeTable()
				} else if phaseIndex == 6 {
					fetchLowPatternTable()
				} else if phaseIndex == 0 {
					fetchHighPatternTable()
					
					currentTileData[(cycle - 1) / 8 + 2] =
						Tile(nameTable: nameTable, attributeTable: attributeTable,
						     patternTableLow: patternTableLow, patternTableHigh: patternTableHigh,
						     vramAddress: currentVramAddress)
					
					incrementX()
				}
			} else {
				backgroundPixelIsTransparent = false
			}
			
			if renderSprites {
				renderSpritePixel(cycle - 1, backgroundPixelTransparent: backgroundPixelIsTransparent)
			}
		} else if cycle <= 320 {
			if cycle == 257 {
				secondaryOAMIndex = 0
				spriteZeroInSecondaryOAM = spriteZeroWillBeInSecondaryOAM
			}
			
			if secondaryOAMIndex < 32 && renderSprites {
				if phaseIndex == 2 {
					spriteYCoord = secondaryOAM[secondaryOAMIndex]
					spriteTileNumber = secondaryOAM[secondaryOAMIndex + 1]
					spriteAttributes = secondaryOAM[secondaryOAMIndex + 2]
					spriteXCoord = secondaryOAM[secondaryOAMIndex + 3]
					
					spriteYShift = scanline - Int(spriteYCoord)
					
					if spriteYCoord == 0xFF {
						spriteYShift = 0
					}
					
					spriteBaseAddress = 0x0000
					
					let verticalFlip = getBit(7, pointer: &spriteAttributes)
					
					if spriteSize {
						// 8x16
						if spriteTileNumber & 0x1 == 1 {
							spriteBaseAddress = 0x1000
							spriteTileNumber = spriteTileNumber - 1
						}
						
						if spriteYShift > 7 {
							// Flip sprite vertically
							if verticalFlip {
								spriteYShift = 15 - spriteYShift
							} else {
								spriteTileNumber += 1
								spriteYShift -= 8
							}
							
						} else if verticalFlip {
							spriteTileNumber += 1
							spriteYShift = 7 - spriteYShift
						}
					} else {
						// 8x8
						if spritePatternTableAddress {
							spriteBaseAddress = 0x1000
						}
						
						// Flip sprite vertically
						if verticalFlip {
							spriteYShift = 7 - spriteYShift
						}
					}
					
					fetchNameTable()
				} else if phaseIndex == 4 {
					fetchNameTable()
				} else if phaseIndex == 6 {
					patternTableLow = ppuMemory.readMemory(spriteBaseAddress + (Int(spriteTileNumber) << 4) + spriteYShift)
				} else if phaseIndex == 0 {
					patternTableHigh = ppuMemory.readMemory(spriteBaseAddress + (Int(spriteTileNumber) << 4) + spriteYShift + 8)
					
					if getBit(6, pointer: &spriteAttributes) {
						patternTableLow = reverseByte(patternTableLow)
						patternTableHigh = reverseByte(patternTableHigh)
					}
					
					currentSpriteData[secondaryOAMIndex / 4] = Sprite(patternTableLow: patternTableLow, patternTableHigh: patternTableHigh, attribute: spriteAttributes, xCoord: spriteXCoord, yCoord: spriteYCoord)
					
					secondaryOAMIndex += 4
				}
			}
		} else if cycle <= 336 {
			if phaseIndex == 2 {
				// Fetch Name Table
				fetchNameTable()
			} else if phaseIndex == 4 {
				fetchAttributeTable()
			} else if phaseIndex == 6 {
				fetchLowPatternTable()
			} else if phaseIndex == 0 {
				fetchHighPatternTable()
				
				let tile = Tile(nameTable: nameTable, attributeTable: attributeTable, patternTableLow: patternTableLow,
				                patternTableHigh: patternTableHigh, vramAddress: currentVramAddress)
				
				if cycle == 328 {
					currentTileData[0] = tile
				} else {
					currentTileData[1] = tile
				}
				
				incrementX()
			}
		} else {
			// TODO: Fetch garbage Name Table byte
		}
	}
	
	func renderSpritePixel(_ currentXCoord: Int, backgroundPixelTransparent: Bool) {
		if !spriteClipping && currentXCoord < 8 {
			return
		}
		
		for i in 0 ..< 8 {
			var sprite = currentSpriteData[i]
			let xCoord = Int(sprite.xCoord)
			
			let xOffset = currentXCoord - xCoord
			
			if xOffset < 0 || xOffset > 7 || xCoord >= 0xFF {
				continue
			}
			
			let lowBit = getBit(7 - xOffset, pointer: &sprite.patternTableLow) ? 1 : 0
			let highBit = getBit(7 - xOffset, pointer: &sprite.patternTableHigh) ? 1 : 0
			
			let attributeBits = Int(sprite.attribute) & 0x3
			
			let patternValue = (attributeBits << 2) | (highBit << 1) | lowBit
			
			let paletteIndex = Int(ppuMemory.readPaletteMemory(0x10 + patternValue)) & 0x3F
			
			// First color each section of sprite palette is transparent
			if patternValue & 0x3 == 0 {
				continue
			}
			
			// TODO: X coordinate of sprites is off slightly
			
			let address = scanline * 256 + xCoord + xOffset
			
			guard address < 256 * 240 else {
				// TODO: Fix
				continue
			}
			
			if spriteZeroInSecondaryOAM && i == 0 && renderBackground && !backgroundPixelTransparent {
				// Sprite 0 and Background is not transparent
				
				// If bits 1 or 2 in PPUMASK are clear and the x coordinate is between 0 and 7, don't hit
				// If x coordinate is 255 or greater, don't hit
				// If y coordinate is 239 or greater, don't hit
				if !((!backgroundClipping || !spriteClipping) && xCoord + xOffset < 8
					&& xCoord + xOffset < 255
					&& sprite.yCoord < 239) {
					sprite0Hit = true
					spriteZeroInSecondaryOAM = false
				}
			}
			
			let backgroundSprite = getBit(5, pointer: &sprite.attribute)
			
			if !backgroundSprite || backgroundPixelTransparent {
				writePixel(xCoord + xOffset, y: scanline, color: colors[paletteIndex])
				return
			} else if backgroundSprite {
				return
			}
		}
	}
	
	func renderBackgroundPixel(_ tile: Tile, tileXCoord: Int, pixelOffset: Int) -> Bool {
		let uPixelOffset = UInt8(pixelOffset)
		
		// Draw pixels from tile
		let patternTableLow = tile.patternTableLow
		let patternTableHigh = tile.patternTableHigh
		
		var pixelXCoord = tileXCoord + pixelOffset - Int(fineXScroll)
		
		if pixelXCoord < 0 {
			pixelXCoord += 256
		}
		
//		let lowBit = getBit(7 - pixelOffset, pointer: &patternTableLow) ? 1 : 0
//		let highBit = getBit(7 - pixelOffset, pointer: &patternTableHigh) ? 1 : 0
		
		let lowBit = Int((patternTableLow >> (7 - uPixelOffset)) & 0x1)
		let highBit = Int((patternTableHigh >> (7 - uPixelOffset)) & 0x1)
		
		let attributeShift = Int(((tile.vramAddress >> 4) & 4) | (tile.vramAddress & 2))
		
		let attributeBits = (Int(tile.attributeTable) >> attributeShift) & 0x3
		
		var patternValue = (attributeBits << 2) | (highBit << 1) | lowBit
		
		if patternValue & 0x3 == 0 || (!backgroundClipping && pixelXCoord < 8) {
			patternValue = 0
		}
		
		let paletteIndex = Int(ppuMemory.readPaletteMemory(patternValue)) & 0x3F
		
		let color = colors[paletteIndex]
		
		writePixel(pixelXCoord, y: scanline, color: color)
		
		return patternValue == 0
	}
	
	func writePixel(_ x: Int, y: Int, color: UInt32) {
		for i in 0 ..< pixelSize {
			for k in 0 ..< pixelSize {
				frame[(y * pixelSize + k) * 256 * pixelSize + x * pixelSize + i] = color
			}
		}		
	}
	
	func fetchNameTable() {
		// Fetch Name Table
		nameTable = ppuMemory.readMemory(0x2000 | (Int(currentVramAddress) & 0x0FFF))
	}
	
	func fetchAttributeTable() {
		// Fetch Attribute Table
		let currentVramAddress = Int(self.currentVramAddress)
		attributeTable = ppuMemory.readMemory(0x23C0 | (currentVramAddress & 0x0C00) | ((currentVramAddress >> 4) & 0x38) | ((currentVramAddress >> 2) & 0x07))
	}
	
	func fetchLowPatternTable() {
		// Fetch lower Pattern Table byte
		var basePatternTableAddress = 0x0000
		
		if backgroundPatternTableAddress {
			basePatternTableAddress = 0x1000
		}
		
		let fineY = (Int(currentVramAddress) >> 12) & 7
		
		patternTableLow = ppuMemory.readMemory(basePatternTableAddress + (Int(nameTable) << 4) + fineY)
	}
	
	func fetchHighPatternTable() {
		// Fetch upper Pattern Table byte
		var basePatternTableAddress = 0x0008
		
		if backgroundPatternTableAddress {
			basePatternTableAddress = 0x1008
		}
		
		let fineY = (Int(currentVramAddress) >> 12) & 7
		
		patternTableHigh = ppuMemory.readMemory(basePatternTableAddress + (Int(nameTable) << 4) + fineY)
	}
	
	func fetchSprite() {
		if cycle % 2 == 0 && scanline != 239 {
			
			let intOAMByte = Int(oamByte)
			let intScanline = Int(scanline)
			
			var spriteHeight = 8
			
			if spriteSize {
				spriteHeight = 16
			}
			
			if intOAMByte < 240 && intOAMByte <= intScanline && intOAMByte + spriteHeight > intScanline {
				
				if secondaryOAMIndex >= 32 {
					if renderSprites {
						// TODO: Handle overflow
						spriteOverflow = true
					}
				} else {
					// Sprite should be drawn on this line
					secondaryOAM[secondaryOAMIndex] = oamByte
					secondaryOAM[secondaryOAMIndex + 1] = oamMemory[4 * oamIndex + 1]
					secondaryOAM[secondaryOAMIndex + 2] = oamMemory[4 * oamIndex + 2]
					secondaryOAM[secondaryOAMIndex + 3] = oamMemory[4 * oamIndex + 3]
					
					if oamIndex == 0 {
						spriteZeroWillBeInSecondaryOAM = true
					}
					
					secondaryOAMIndex += 4
				}
			} else if secondaryOAMIndex >= 32 {
				oamIndexOverflow += 1
				
				if oamIndexOverflow >= 4 {
					oamIndexOverflow = 0
				}
			}
			
			oamIndex += 1
			
			if oamIndex >= 64 {
				oamIndex = 0
				oamStage = 1
				
				while secondaryOAMIndex < 32 {
					secondaryOAM[secondaryOAMIndex] = 0xFF
					secondaryOAM[secondaryOAMIndex + 1] = 0xFF
					secondaryOAM[secondaryOAMIndex + 2] = 0xFF
					secondaryOAM[secondaryOAMIndex + 3] = 0xFF
					
					secondaryOAMIndex += 4
				}
			}
			
		} else {
			oamByte = oamMemory[4 * oamIndex + oamIndexOverflow]
		}
	}
	
	func incrementY() {
		// If fine Y < 7
		if (currentVramAddress & 0x7000) != 0x7000 {
			// Increment fine Y
			currentVramAddress = UInt16((Int(currentVramAddress) + 0x1000) & 0xFFFF)
		} else {
			// Fine Y = 0
			currentVramAddress &= 0x8FFF
			// var y = coarse Y
			var y = (currentVramAddress & 0x03E0) >> 5
			if y == 29 {
				// Coarse Y = 0
				y = 0
				// Switch vertical nametable
				self.currentVramAddress ^= 0x0800
			} else if y == 31 {
				// Coarse Y = 0, nametable not switched
				y = 0
			} else {
				// Increment coarse Y
				y += 1
			}
			
			// Put coarse Y back into v
			currentVramAddress = (currentVramAddress & 0xFC1F) | (y << 5)
		}

	}
	
	func incrementX() {
		// If coarse X == 31
		if (currentVramAddress & 0x001F) == 31 {
			// Coarse X = 0
			currentVramAddress &= 0xFFE0
			
			// Switch horizontal nametable
			currentVramAddress ^= 0x0400
		} else {
			// Increment coarse X
			currentVramAddress += 1
		}
	}
	
	func copyY() {
		currentVramAddress = (currentVramAddress & 0x841F) | (tempVramAddress & 0x7BE0)
	}
	
	func copyX() {
		currentVramAddress = (currentVramAddress & 0xFBE0) | (tempVramAddress & 0x041F)
	}
	
	func writeDMA(_ address: Int, data: UInt8) {
		oamMemory[address] = data
	}
	
	// MARK - Registers
	
	func setBit(_ index: Int, value: Bool, pointer: UnsafeMutablePointer<UInt8>) {
		let bit: UInt8 = value ? 0xFF : 0
		pointer.pointee ^= (bit ^ pointer.pointee) & (1 << UInt8(index))
	}
	
	func getBit(_ index: Int, pointer: UnsafePointer<UInt8>) -> Bool {
		return ((pointer.pointee >> UInt8(index)) & 0x1) == 1
	}
	
	/**
	 Bit level reverses the given byte
	 From http://stackoverflow.com/a/2602885
	*/
	func reverseByte(_ value: UInt8) -> UInt8 {
		var b = (value & 0xF0) >> 4 | (value & 0x0F) << 4
		b = (b & 0xCC) >> 2 | (b & 0x33) << 2
		b = (b & 0xAA) >> 1 | (b & 0x55) << 1
		return b
	}
	
	func cpuWrite(_ index: Int, data: UInt8) {
		switch index {
			case 0:
				PPUCTRL = data
			case 1:
				PPUMASK = data
			case 2:
				break
			case 3:
				OAMADDR = data
			case 4:
				OAMDATA = data
			case 5:
				PPUSCROLL = data
			case 6:
				PPUADDR = data
			case 7:
				PPUDATA = data
			default:
				print("ERROR: Invalid CPU write index")
		}
		
		// Update decay register
		lastWrittenRegisterValue = data
		lastWrittenRegisterDecayed = false
		lastWrittenRegisterSetCycle = 0
	}
	
	func readPPUSTATUS() -> UInt8 {
		var temp = (lastWrittenRegisterValue & 0x1F)
		
		temp |= spriteOverflow ? 0x20 : 0
		temp |= sprite0Hit ? 0x40: 0
		temp |= vblank ? 0x80: 0
		
		// Clear VBlank flag
		vblank = false
		
		writeToggle = false
		
		nmiChange()
		
		if scanline == 241 {
			if cycle == 0 {
				suppressVBlankFlag = true
			} else if cycle == 1 && cyclesSinceNMI != -1 {
				cpu.clearNMI()
			}
		}
		
		return temp
	}
	
	func readWriteOnlyRegister() -> UInt8 {
		// Reading any write only register should return last written value to a PPU register
		return lastWrittenRegisterValue
	}
	
	func readOAMDATA() -> UInt8 {
		var value = oamMemory[Int(OAMADDR)]
		
		if OAMADDR % 4 == 2 {
			value = value & 0xE3
			
			lastWrittenRegisterValue = value
			lastWrittenRegisterDecayed = false
			lastWrittenRegisterSetCycle = 0
		}
		
		return value
	}
	
	func readPPUDATA() -> UInt8 {
		// TODO: Switch back to currentVramAddress
		var value = ppuMemory.readMemory(Int(currentPPUADDRAddress))
		
		if currentPPUADDRAddress % 0x4000 < 0x3F00 {
			let buffered = ppuDataReadBuffer
			ppuDataReadBuffer = value
			value = buffered
		} else {
			ppuDataReadBuffer = ppuMemory.readMemory(Int(currentPPUADDRAddress) - 0x1000)
//			value = (self.ppuDataReadBuffer & 0x3F) | (self.lastWrittenRegisterValue & 0xC0)
		}
		
		let temp = currentPPUADDRAddress
		
		if vramIncrement {
			currentPPUADDRAddress += 32
		} else {
			currentPPUADDRAddress += 1
		}
		
		a12(currentPPUADDRAddress, old: temp)
		
		// Update decay register
		lastWrittenRegisterValue = value
		lastWrittenRegisterDecayed = false
		
		return value
	}

	/**
		Exists as an optimization over having a standard public field
	*/
	func getScanline() -> Int {
		return scanline
	}

	/**
		Exists as an optimization over having a standard public field
	*/
	func getCycle() -> Int {
		return cycle
	}
	
	func getRenderingEnabled() -> Bool {
		return renderBackground || renderSprites
	}
	
	private func a12(_ new: UInt16, old: UInt16) {
		if new & 0x1000 == 0x1000 && old & 0x1000 == 0 {
			if ppuMemory.a12Timer == 0 {
				ppuMemory.mapper.step()
			}
			
			ppuMemory.a12Timer = 16
		}
	}
	
	func dumpMemory() {
		ppuMemory.dumpMemory()
	}
	
	func setRenderScale(_ scale: Int) {
		pixelSize = scale
		totalPixelCount = 256 * 240 * scale * scale
		
		frame = [UInt32](repeating: 0, count: totalPixelCount)
	}
}
