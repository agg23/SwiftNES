//
//  FileIO.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation
import Cocoa

final class FileIO: NSObject {
	
	let mainMemory: Memory;
	let ppuMemory: Memory;
	
	init(mainMemory: Memory, ppuMemory: Memory) {
		self.mainMemory = mainMemory;
		self.ppuMemory = ppuMemory;
	}
	
	func loadFile(path: String) -> Bool {
		let data = NSFileManager.defaultManager().contentsAtPath(path);
		
		if(data == nil) {
			print("File failed to load");
			return false;
		}
		
		let count = data!.length / sizeof(UInt8);
		var bytes = [UInt8](count: count, repeatedValue: 0);
		
		data?.getBytes(&bytes, length: data!.length * sizeof(UInt8));
		
		// NES(escape) in little endian
		if(bytes[0] != 0x4E || bytes[1] != 0x45 || bytes[2] != 0x53 || bytes[3] != 0x1A) {
			print("Invalid input file, does not contain NES header");
			return false;
		}
		
		let prgBanks = bytes[4];
		
		if(prgBanks == 1) {
			self.mainMemory.mirrorPRGROM = true;
		}
		
		let chrBanks = bytes[5];
		let misc = bytes[6];
		
		let verticalMirroring = misc & 0x1 == 1;
		
		if(verticalMirroring) {
			self.ppuMemory.nametableMirroring = .Vertical;
		} else {
			self.ppuMemory.nametableMirroring = .Horizontal;
		}
		
		// Battery Backed RAM at $6000 - $7FFF
		let batteryBackedRAM = misc & 0x2 == 1;
		
		// 512-byte trainer at $7000-$71FF
		let trainer = misc & 0x4 == 1;
		
		let fourScreenVRAM = misc & 0x8 == 1;
		
		let romMapperLower = (misc & 0xF0) >> 4;
		
		let misc2 = bytes[7];
		
		// This cartridge is for a Nintendo VS System
		let nesVSSystem = misc2 & 0x1 == 1;
		
		let romMapperUpper = (misc2 & 0xF0) >> 4;
		
		let romMapper = (romMapperUpper << 4) + romMapperLower;
		
		let ramBanks = bytes[8];
		
		let NTSC = bytes[9] == 0;
		
		print("PRG Banks: \(prgBanks), CHR Banks: \(chrBanks)");
		print("Vertical Mirroring: \(verticalMirroring), Battery Backed RAM: \(batteryBackedRAM)");
		print("Trainer: \(trainer), Four Screen VRAM: \(fourScreenVRAM), NES VS System: \(nesVSSystem)");
		print("ROM Mapper \(romMapper), RAM Banks: \(ramBanks), NTSC: \(NTSC)");
		
		let prgOffset = Int(prgBanks) * 0x4000;
		
		self.mainMemory.banks = [UInt8](count: prgOffset, repeatedValue: 0);
		self.ppuMemory.banks = [UInt8](count: Int(chrBanks) * 0x2000, repeatedValue: 0);
		
		for i in 0 ..< prgOffset {
			self.mainMemory.banks[i] = bytes[16 + i];
		}
		
		for i in 0 ..< Int(chrBanks) * 0x2000 {
			self.ppuMemory.banks[i] = bytes[prgOffset + 16 + i];
		}
		
		print("Memory initialized");
		
		return true;
	}
}
