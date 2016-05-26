//
//  Mapper1.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/25/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Mapper1: Mapper {
	
	// MARK: - Internal Registers
	
	private var shiftRegister: UInt8;
	private var control: UInt8 {
		didSet {
			let mirroring = control & 0x3;
			
			switch(mirroring) {
				case 0:
					self.ppuMemory!.nametableMirroring = .OneScreen;
					self.oneScreenUpper = false;
				case 1:
					self.ppuMemory!.nametableMirroring = .OneScreen;
					self.oneScreenUpper = true;
				case 2:
					self.ppuMemory!.nametableMirroring = .Vertical;
				case 3:
					self.ppuMemory!.nametableMirroring = .Horizontal;
				default:
					break;
			}
			
			self.prgRomBankMode = (control & 0xC) >> 2;
			self.chrRomBankMode = control & 0x10 == 0x10;
			
			updateOffsets();
		}
	};
	
	private var oneScreenUpper: Bool;
	private var prgRomBankMode: UInt8;
	private var chrRomBankMode: Bool;
	
	private var chrBank0: UInt8;
	private var chrBank1: UInt8;
	
	private var prgBank: UInt8;
	
	private var chrBank0Offset: Int;
	private var chrBank1Offset: Int;
	private var prgBank0Offset: Int;
	private var prgBank1Offset: Int;
	
	override var cpuMemory: CPUMemory? {
		didSet {
			self.prgBank1Offset = cpuMemory!.banks.count - 0x4000;
		}
	}
	
	override var ppuMemory: PPUMemory? {
		didSet {
			let count = ppuMemory!.banks.count;
			
			if(count == 0) {
				self.chrBank1Offset = 0x1000;
			} else {
				self.chrBank1Offset = ppuMemory!.banks.count - 0x4000;
			}
		}
	}
	
	override init() {
		self.shiftRegister = 0x10;
		self.control = 0;
		
		self.oneScreenUpper = false;
		self.prgRomBankMode = 0;
		self.chrRomBankMode = false;
		
		self.chrBank0 = 0;
		self.chrBank1 = 0;
		
		self.prgBank = 0;
		
		self.chrBank0Offset = 0;
		self.chrBank1Offset = 0;
		self.prgBank0Offset = 0;
		self.prgBank1Offset = 0;
	}
	
	override func cpuRead(address: Int) -> UInt8 {
		switch(address) {
			case 0x0000 ..< 0x1000:
				return self.ppuMemory!.banks[self.chrBank0Offset + address];
			case 0x1000 ..< 0x2000:
				return self.ppuMemory!.banks[self.chrBank1Offset + address - 0x1000];
			case 0x2000 ..< 0x6000:
				print("Invalid mapper 1 address \(address)");
			case 0x6000 ..< 0x8000:
				return self.cpuMemory!.sram[address - 0x6000];
			case 0x8000 ..< 0xC000:
				return self.cpuMemory!.banks[self.prgBank0Offset + address - 0x8000];
			case 0xC000 ..< 0x10000:
				return self.cpuMemory!.banks[self.prgBank1Offset + address - 0xC000];
			default:
				break;
		}
		
		return 0;
	}
	
	override func cpuWrite(address: Int, data: UInt8) {
		switch(address) {
			case 0x0000 ..< 0x1000:
				self.ppuMemory!.banks[self.chrBank0Offset + address] = data;
			case 0x1000 ..< 0x2000:
				self.ppuMemory!.banks[self.chrBank1Offset + address - 0x1000] = data;
			case 0x2000 ..< 0x6000:
				print("Invalid mapper 1 address \(address)");
			case 0x6000 ..< 0x8000:
				self.cpuMemory!.sram[address - 0x6000] = data;
			case 0x8000 ..< 0x10000:
				updateShiftRegister(address, data: data);
			default:
				break;
		}
	}
	
	private func updateShiftRegister(address: Int, data: UInt8) {
		if(data & 0x80 == 0x80) {
			self.shiftRegister = 0x10;
			self.control = self.control | 0x0C;
		} else {
			let writeComplete = self.shiftRegister & 0x1 == 0x1;
			self.shiftRegister = self.shiftRegister >> 1;
			self.shiftRegister = self.shiftRegister | ((data & 0x1) << 4);
			
			if(writeComplete) {
				writeInternalRegister(address, data: data);
				self.shiftRegister = 0x10;
			}
		}
	}
	
	private func writeInternalRegister(address: Int, data: UInt8) {
		if(address < 0xA000) {
			// Control
			self.control = self.shiftRegister;
		} else if(address < 0xC000) {
			// CHR bank 0
			self.chrBank0 = self.shiftRegister;
			
			if(!self.chrRomBankMode) {
				self.chrBank0 = self.chrBank0 & 0xFE;
			}
		} else if(address < 0xE000) {
			// CHR bank 1
			self.chrBank1 = self.shiftRegister;
		} else {
			// PRG bank
			self.prgBank = self.shiftRegister;
			
			if(self.prgRomBankMode & 0x2 == 0) {
				self.prgBank = self.prgBank & 0xFE;
			}
		}
		
		updateOffsets();
	}
	
	private func updateOffsets() {
		self.chrBank0Offset = Int(self.chrBank0) * 0x1000;
		
		if(self.chrRomBankMode) {
			self.chrBank1Offset = Int(self.chrBank1) * 0x1000;
		} else {
			self.chrBank1Offset = self.chrBank0Offset;
		}
		
		switch(self.prgRomBankMode) {
			case 0, 1:
				self.prgBank0Offset = Int(self.prgBank) * 0x4000;
				self.prgBank1Offset = self.prgBank0Offset + 0x4000;
			case 2:
				self.prgBank0Offset = 0;
				self.prgBank1Offset = Int(self.prgBank) * 0x4000;
			case 3:
				self.prgBank0Offset = Int(self.prgBank) * 0x4000;
				self.prgBank1Offset = self.cpuMemory!.banks.count - 0x4000;
			default:
				break;
		}
	}
}