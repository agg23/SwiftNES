//
//  Mapper9.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/30/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Mapper9: Mapper {
	private var prgBankOffset: Int;
	private var prgBankLastOffset: Int;
	
	private var chrBank0Offset: Int;
	private var chrBank1Offset: Int;
	
	private var latch0: Bool;
	private var latch1: Bool;
	private var chrBank0FD: Int;
	private var chrBank0FE: Int;
	private var chrBank1FD: Int;
	private var chrBank1FE: Int;
	
	override var cpuMemory: CPUMemory? {
		didSet {
			self.prgBankLastOffset = cpuMemory!.banks.count - 0x2000;
		}
	}
	
	override init() {
		self.prgBankOffset = 0;
		self.prgBankLastOffset = 0;
		
		self.chrBank0Offset = 0;
		self.chrBank1Offset = 0;
		
		self.latch0 = false;
		self.latch1 = false;
		self.chrBank0FD = 0;
		self.chrBank0FE = 0;
		self.chrBank1FD = 0;
		self.chrBank1FE = 0;
	}
	
	override func read(address: Int) -> UInt8 {
		switch(address) {
			case 0x0000 ..< 0x1000:
				let temp = self.ppuMemory!.banks[self.chrBank0Offset + address];
				
				if(address == 0xFD8) {
					self.latch0 = false;
					updateCHRBanks();
				} else if(address == 0xFE8) {
					self.latch0 = true;
					updateCHRBanks();
				}
				
				return temp;
			case 0x1000 ..< 0x2000:
				let temp = self.ppuMemory!.banks[self.chrBank1Offset + address - 0x1000];
				if(address > 0x1FD7 && address < 0x1FE0) {
					self.latch1 = false;
					updateCHRBanks();
				} else if(address > 0x1FE7 && address < 0x1FF0) {
					self.latch1 = true;
					updateCHRBanks();
				}
				
				return temp;
			case 0x2000 ..< 0x6000:
				print("Invalid mapper 9 address \(address)");
			case 0x6000 ..< 0x8000:
				return self.cpuMemory!.sram[address - 0x6000];
			case 0x8000 ..< 0xA000:
				return self.cpuMemory!.banks[self.prgBankOffset + address - 0x8000];
			case 0xA000 ..< 0xC000:
				return self.cpuMemory!.banks[self.prgBankLastOffset + address - 0xE000];
			case 0xC000 ..< 0xE000:
				return self.cpuMemory!.banks[self.prgBankLastOffset + address - 0xE000];
			case 0xE000 ..< 0x10000:
				return self.cpuMemory!.banks[self.prgBankLastOffset + address - 0xE000];
			default:
				break;
		}
		
		return 0;
	}
	
	override func write(address: Int, data: UInt8) {
		switch(address) {
			case 0x0000 ..< 0x1000:
				self.ppuMemory!.banks[self.chrBank0Offset + address] = data;
			case 0x1000 ..< 0x2000:
				self.ppuMemory!.banks[self.chrBank1Offset + address - 0x1000] = data;
			case 0x2000 ..< 0x6000:
				print("Invalid mapper 9 address \(address)");
			case 0x6000 ..< 0x8000:
				self.cpuMemory!.sram[address - 0x6000] = data;
			case 0x8000 ..< 0xA000:
				print("Invalid mapper 9 address \(address)");
			case 0xA000 ..< 0xB000:
				setPRGBank(data);
			case 0xB000 ..< 0xC000:
				self.chrBank0FD = Int(data) & 0x1F;
				updateCHRBanks();
			case 0xC000 ..< 0xD000:
				self.chrBank0FE = Int(data) & 0x1F;
				updateCHRBanks();
			case 0xD000 ..< 0xE000:
				self.chrBank1FD = Int(data) & 0x1F;
				updateCHRBanks();
			case 0xE000 ..< 0xF000:
				self.chrBank1FE = Int(data) & 0x1F;
				updateCHRBanks();
			case 0xF000 ..< 0xA0000:
				setMirroring(data);
			default:
				break;
		}
	}
	
	func setPRGBank(data: UInt8) {
		self.prgBankOffset = (Int(data) & 0xF) * 0x2000;
	}
	
	func updateCHRBanks() {
		if(self.latch0) {
			// FE
			self.chrBank0Offset = self.chrBank0FE * 0x1000;
		} else {
			// FD
			self.chrBank0Offset = self.chrBank0FD * 0x1000;
		}
		
		if(self.latch1) {
			// FE
			self.chrBank1Offset = self.chrBank1FE * 0x1000;
		} else {
			// FD
			self.chrBank1Offset = self.chrBank1FD * 0x1000;
		}
	}
	
	func setMirroring(data: UInt8) {
		if(data & 0x1 == 0x1) {
			self.ppuMemory!.nametableMirroring = .Horizontal;
		} else {
			self.ppuMemory!.nametableMirroring = .Vertical;
		}
	}
}