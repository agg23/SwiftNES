//
//  PPU.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 4/2/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

class PPU: NSObject {
	/*
	 PPU Control Register
	*/
	var PPUCTRL: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2000] = PPUCTRL;
		}
	}
	
	/*
	 PPU Mask Register
	*/
	var PPUMASK: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2001] = PPUMASK;
		}
	}

	/*
	 PPU Status Register
	*/
	var PPUSTATUS: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2002] = PPUSTATUS;
		}
	}
	
	/*
	 OAM Address Port
	*/
	var OAMADDR: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2003] = OAMADDR;
		}
	}
	
	/*
	 OAM Data Port
	*/
	var OAMDATA: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2004] = OAMDATA;
		}
	}
	
	/*
	 PPU Scrolling Position Register
	*/
	var PPUSCROLL: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2005] = PPUSCROLL;
		}
	}
	
	/*
	 PPU Address Register
	*/
	var PPUADDR: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2006] = PPUADDR;
		}
	}
	
	/*
	 PPU Data Port
	*/
	var PPUDATA: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2007] = PPUDATA;
		}
	}
	
	/*
	 OAM DMA Register
	*/
	var OAMDMA: UInt8 {
		didSet {
			self.cpuMemory.writeMemory(0x4014, data: OAMDMA);
		}
	}
	
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
	var frame: [[Int]];
	
	let cpuMemory: Memory;
	let ppuMemory: Memory;
	
	init(cpuMemory: Memory, ppuMemory: Memory) {
		self.cpuMemory = cpuMemory;
		self.ppuMemory = ppuMemory;
		
		self.PPUCTRL = 0;
		self.PPUMASK = 0;
		self.PPUSTATUS = 0;
		self.OAMADDR = 0;
		self.OAMDATA = 0;
		self.PPUSCROLL = 0;
		self.PPUADDR = 0;
		self.PPUDATA = 0;
		self.OAMDMA = 0;
		
		self.scanline = 0;
		self.pixelIndex = 0;
		
		self.frame = [[Int]](count:256, repeatedValue:[Int](count:240, repeatedValue:0));
	}
	
	func reset() {
		
	}
	
	func renderScanline() {
		if(scanline < 20) {
			// VBlank period
			
			scanline += 1;
			return;
		} else if(scanline == 20) {
			// TODO: Update horizontal and vertical scroll counters
			
			scanline += 1;
			return;
		} else if(scanline == 261) {
			scanline = 0;
			return;
		}
		
		// Load playfield
		for i in 0 ..< 32 {
			var nameTable = self.ppuMemory.readMemory(0x2000 + scanline / 8 + i);
			var attributeTable = self.ppuMemory.readMemory(0x23C0 + i);
			
			var patternTableBitmapLow = self.ppuMemory.readMemory(0x0000 + Int(nameTable));
			var patternTableBitmapHigh = self.ppuMemory.readMemory(0x0000 + Int(nameTable) + 1);
			
			
		}
		
		// Load objects for next scanline
		for i in 0 ..< 8 {
			// TODO: Load objects
		}
		
		// Load first two tiles of playfield for next scanline
		for i in 0 ..< 2 {
			var nameTable = self.ppuMemory.readMemory(0x2000 + scanline / 8 + i);
			var attributeTable = self.ppuMemory.readMemory(0x23C0 + i);
			
			var patternTableOne = self.ppuMemory.readMemory(0x0000 + Int(nameTable));
			var patternTableTwo = self.ppuMemory.readMemory(0x1000 + Int(nameTable));
		}
		
		scanline += 1;
	}
}