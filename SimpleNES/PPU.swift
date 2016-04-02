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
	}
}