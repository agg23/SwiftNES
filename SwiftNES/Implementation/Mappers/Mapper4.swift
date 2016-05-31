//
//  Mapper4.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/31/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Mapper4: Mapper {
	
	override var cpuMemory: CPUMemory? {
		didSet {
			self.prgBankLastOffset = cpuMemory!.banks.count - 0x2000;
			
			updateOffsets();
		}
	}
	
	
	private var register0: UInt8;
	private var register1: UInt8;
	private var register2: UInt8;
	private var register3: UInt8;
	private var register4: UInt8;
	private var register5: UInt8;
	private var register6: UInt8;
	private var register7: UInt8;
	
	private var irqLoadRegister: UInt8;
	private var irqCounter: UInt8;
	private var irqShouldReload: Bool;
	private var irqDisable: Bool;
	
	private var prgBank0: UInt8;
	private var prgBank1: UInt8;
	private var prgBank2: UInt8;
	
	private var prgBank0Offset: Int;
	private var prgBank1Offset: Int;
	private var prgBank2Offset: Int;
	private var prgBankLastOffset: Int;
	
	private var chrBank0Offset: Int;
	private var chrBank1Offset: Int;
	private var chrBank2Offset: Int;
	private var chrBank3Offset: Int;
	private var chrBank4Offset: Int;
	private var chrBank5Offset: Int;
	private var chrBank6Offset: Int;
	private var chrBank7Offset: Int;
	
	private var selectedBank: Int;
	private var prgBankMode: Bool;
	private var chrBankMode: Bool;
	
	override init() {
		self.register0 = 0;
		self.register1 = 0;
		self.register2 = 0;
		self.register3 = 0;
		self.register4 = 0;
		self.register5 = 0;
		self.register6 = 0;
		self.register7 = 0;
		
		self.irqLoadRegister = 0;
		self.irqCounter = 0;
		self.irqShouldReload = false;
		self.irqDisable = true;
		
		self.prgBank0 = 0;
		self.prgBank1 = 0;
		self.prgBank2 = 0;
		
		self.prgBank0Offset = 0;
		self.prgBank1Offset = 0;
		self.prgBank2Offset = 0;
		self.prgBankLastOffset = 0;
		
		self.chrBank0Offset = 0;
		self.chrBank1Offset = 0;
		self.chrBank2Offset = 0;
		self.chrBank3Offset = 0;
		self.chrBank4Offset = 0;
		self.chrBank5Offset = 0;
		self.chrBank6Offset = 0;
		self.chrBank7Offset = 0;
		
		self.selectedBank = 0;
		self.prgBankMode = false;
		self.chrBankMode = false;
	}
	
	override func read(address: Int) -> UInt8 {
		switch(address) {
			case 0x0000 ..< 0x400:
				return self.ppuMemory!.banks[self.chrBank0Offset + address];
			case 0x400 ..< 0x800:
				return self.ppuMemory!.banks[self.chrBank1Offset + address - 0x400];
			case 0x800 ..< 0xC00:
				return self.ppuMemory!.banks[self.chrBank2Offset + address - 0x800];
			case 0xC00 ..< 0x1000:
				return self.ppuMemory!.banks[self.chrBank3Offset + address - 0xC00];
			case 0x1000 ..< 0x1400:
				return self.ppuMemory!.banks[self.chrBank4Offset + address - 0x1000];
			case 0x1400 ..< 0x1800:
				return self.ppuMemory!.banks[self.chrBank5Offset + address - 0x1400];
			case 0x1800 ..< 0x1C00:
				return self.ppuMemory!.banks[self.chrBank6Offset + address - 0x1800];
			case 0x1C00 ..< 0x2000:
				return self.ppuMemory!.banks[self.chrBank7Offset + address - 0x1C00];
			case 0x2000 ..< 0x6000:
				print("Invalid mapper 4 address \(address)");
			case 0x6000 ..< 0x8000:
				return self.cpuMemory!.sram[address - 0x6000];
			case 0x8000 ..< 0xA000:
				return self.cpuMemory!.banks[self.prgBank0Offset + address - 0x8000];
			case 0xA000 ..< 0xC000:
				return self.cpuMemory!.banks[self.prgBank1Offset + address - 0xA000];
			case 0xC000 ..< 0xE000:
				return self.cpuMemory!.banks[self.prgBank2Offset + address - 0xC000];
			case 0xE000 ..< 0x10000:
				return self.cpuMemory!.banks[self.prgBankLastOffset + address - 0xE000];
			default:
				break;
		}
		
		return 0;
	}
	
	override func write(address: Int, data: UInt8) {
		switch(address) {
			case 0x0000 ..< 0x400:
				self.ppuMemory!.banks[self.chrBank0Offset + address] = data;
			case 0x800 ..< 0x1000:
				self.ppuMemory!.banks[self.chrBank1Offset + address - 0x800] = data;
			case 0x1000 ..< 0x1400:
				self.ppuMemory!.banks[self.chrBank2Offset + address - 0x1000] = data;
			case 0x1400 ..< 0x1800:
				self.ppuMemory!.banks[self.chrBank3Offset + address - 0x1400] = data;
			case 0x1800 ..< 0x1C00:
				self.ppuMemory!.banks[self.chrBank4Offset + address - 0x1800] = data;
			case 0x1C00 ..< 0x2000:
				self.ppuMemory!.banks[self.chrBank5Offset + address - 0x1C00] = data;
			case 0x2000 ..< 0x6000:
				print("Invalid mapper 4 address \(address)");
			case 0x6000 ..< 0x8000:
				self.cpuMemory!.sram[address - 0x6000] = data;
			case 0x8000 ..< 0xA000:
				if(address % 2 == 0) {
					bankSelect(data);
				} else {
					bankData(data);
				}
			case 0xA000 ..< 0xC000:
				if(address % 2 == 0) {
					setMirroring(data);
				} else {
					// TODO: Handle PRG RAM protection
				}
			case 0xC000 ..< 0xE000:
				if(address % 2 == 0) {
					self.irqLoadRegister = data;
				} else {
					self.irqShouldReload = true;
				}
			case 0xE000 ..< 0x10000:
				if(address % 2 == 0) {
					self.irqDisable = true;
					self.cpuMemory!.ppu!.cpu!.clearIRQ();
				} else {
					self.irqDisable = false;
				}
			default:
				break;
		}
	}
	
	private func bankSelect(data: UInt8) {
		self.selectedBank = Int(data & 0x7);
		
		self.prgBankMode = data & 0x40 == 0x40;
		self.chrBankMode = data & 0x80 == 0x80;
	}
	
	private func bankData(data: UInt8) {
		switch(self.selectedBank) {
			case 0:
				self.register0 = data;
			case 1:
				self.register1 = data;
			case 2:
				self.register2 = data;
			case 3:
				self.register3 = data;
			case 4:
				self.register4 = data;
			case 5:
				self.register5 = data;
			case 6:
				self.register6 = data;
			case 7:
				self.register7 = data;
			default:
				break;
		}
		
		updateOffsets();
	}
	
	private func setMirroring(data: UInt8) {
		if(self.ppuMemory!.nametableMirroring != .FourScreen) {
			if(data & 0x1 == 0x1) {
				self.ppuMemory!.nametableMirroring = .Horizontal;
			} else {
				self.ppuMemory!.nametableMirroring = .Vertical;
			}
		}
	}
	
	private func updateOffsets() {
		if(self.chrBankMode) {
			self.chrBank0Offset = Int(self.register2) * 0x400;
			self.chrBank1Offset = Int(self.register3) * 0x400;
			self.chrBank2Offset = Int(self.register4) * 0x400;
			self.chrBank3Offset = Int(self.register5) * 0x400;
			self.chrBank4Offset = Int(self.register0 & 0xFE) * 0x400;
			self.chrBank5Offset = Int(self.register0 | 0x1) * 0x400;
			self.chrBank6Offset = Int(self.register1 & 0xFE) * 0x400;
			self.chrBank7Offset = Int(self.register1 | 0x1) * 0x400;
		} else {
			self.chrBank0Offset = Int(self.register0 & 0xFE) * 0x400;
			self.chrBank1Offset = Int(self.register0 | 0x1) * 0x400;
			self.chrBank2Offset = Int(self.register1 & 0xFE) * 0x400;
			self.chrBank3Offset = Int(self.register1 | 0x1) * 0x400;
			self.chrBank4Offset = Int(self.register2) * 0x400;
			self.chrBank5Offset = Int(self.register3) * 0x400;
			self.chrBank6Offset = Int(self.register4) * 0x400;
			self.chrBank7Offset = Int(self.register5) * 0x400;
		}
		
		if(self.prgBankMode) {
			self.prgBank0Offset = self.prgBankLastOffset - 0x2000;
			self.prgBank2Offset = Int(self.register6) * 0x2000;
		} else {
			self.prgBank0Offset = Int(self.register6) * 0x2000;
			self.prgBank2Offset = self.prgBankLastOffset - 0x2000;
		}
		
		self.prgBank1Offset = Int(self.register7) * 0x2000;
	}
	
	// MARK: - IRQ Handling
	
	override func step() {
		let ppu = self.cpuMemory!.ppu!;
		let scanline = ppu.getScanline();
		
		if(scanline > 239 && scanline < 261 || ppu.getCycle() != 260 || !ppu.getRenderingEnabled()) {
			return;
		}
		
		if(self.irqShouldReload) {
			self.irqCounter = self.irqLoadRegister;
			self.irqShouldReload = false;
		} else if(self.irqCounter == 0) {
			self.irqCounter = self.irqLoadRegister;
		} else {
			self.irqCounter -= 1;
			
			if(self.irqCounter == 0 && !self.irqDisable) {
				self.cpuMemory!.ppu!.cpu!.queueIRQ();
			}
		}
	}
}