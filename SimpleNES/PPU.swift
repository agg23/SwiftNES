//
//  PPU.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 4/2/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

class PPU: NSObject {
	/**
	 PPU Control Register
	*/
	var PPUCTRL: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2000] = PPUCTRL;
		}
	}
	
	/**
	 PPU Mask Register
	*/
	var PPUMASK: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2001] = PPUMASK;
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
		}
	}
	
	/**
	 OAM Data Port
	*/
	var OAMDATA: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2004] = OAMDATA;
			writeOAMDATA = true;
		}
	}
	
	/**
	 PPU Scrolling Position Register
	*/
	var PPUSCROLL: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2005] = PPUSCROLL;
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
		}
	}
	
	/**
	 PPU Data Port
	*/
	var PPUDATA: UInt8 {
		didSet {
			self.cpuMemory.memory[0x2007] = PPUDATA;
			self.ppuMemory.writeMemory(Int(self.vramAddress), data: PPUDATA);
		}
	}
	
	/*
	 OAM DMA Register
	*/
	var OAMDMA: UInt8 {
		didSet {
			self.cpuMemory.writeMemory(0x4014, data: OAMDMA);
			dmaCopy();
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
	var frame: [[Int]];
	
	var cpu: CPU?;
	let cpuMemory: Memory;
	let ppuMemory: Memory;
	let oamMemory: Memory;
	
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
		self.PPUSTATUS = 0xA0;
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
			if(scanline == 0 && (self.PPUCTRL & 0x80) == 0x80) {
				// NMI enabled
				self.cpu!.queueInterrupt(CPU.Interrupt.VBlank);
				
				// Set VBlank flag
				setBit(7, value: true, pointer: &self.PPUSTATUS);
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
	
	// MARK - Registers
	
	func setBit(index: Int, value: Bool, pointer: UnsafeMutablePointer<UInt8>) {
		let bit: UInt8 = value ? 0xFF : 0;
		pointer.memory ^= (bit ^ pointer.memory) & (1 << UInt8(index));
	}
	
	func getBit(index: Int, pointer: UnsafeMutablePointer<UInt8>) -> Bool {
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