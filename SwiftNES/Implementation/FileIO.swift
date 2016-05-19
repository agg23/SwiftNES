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
		
		let count = data!.length / sizeof(UInt32);
		var bytes = [UInt32](count: count, repeatedValue: 0);
		
		data?.getBytes(&bytes, length: data!.length * sizeof(UInt32));
		
		let nesHead = bytes[0];
		
		// NES(escape) in little endian
		if(nesHead != 0x1a53454e) {
			print("Invalid input file, does not contain NES header");
			return false;
		}
		
		let banksHead = bytes[1];
		
		let romBanks = UInt8(banksHead & 0xFF);
		
		if(romBanks == 1) {
			self.mainMemory.mirrorPRGROM = true;
		}
		
		let vROMBanks = UInt8((banksHead & 0xFF00) >> 8);
		let misc = UInt8((banksHead & 0xFF0000) >> 16);
		
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
		
		let misc2 = UInt8((banksHead & 0xFF000000) >> 24);
		
		// This cartridge is for a Nintendo VS System
		let nesVSSystem = misc2 & 0x1 == 1;
		
		let romMapperUpper = (misc2 & 0xF0) >> 4;
		
		let romMapper = (romMapperUpper << 4) + romMapperLower;
		
		let ramBanksHead = bytes[2];
		
		let ramBanks = ramBanksHead & 0xF;
		
		let NTSC = ((ramBanksHead & 0x10) >> 4) == 0;
		
		print("ROM Banks: \(romBanks), VROM Banks: \(vROMBanks)");
		print("Vertical Mirroring: \(verticalMirroring), Battery Backed RAM: \(batteryBackedRAM)");
		print("Trainer: \(trainer), Four Screen VRAM: \(fourScreenVRAM), NES VS System: \(nesVSSystem)");
		print("ROM Mapper \(romMapper), RAM Banks: \(ramBanks), NTSC: \(NTSC)");
		
//		var b = bytes[4];
		
		var i = 0;
		
		let romEndingOffset = Int(romBanks) * 0x4000;
		
		while(i < count - 4) {
			let b = bytes[4 + i];
			let offset = i * 4;
			
			if(offset+3 > romEndingOffset) {
				// Remaining data is VROM
				
				self.ppuMemory.writeMemory(0x0 + offset - romEndingOffset, data: UInt8(b & 0xFF));
				self.ppuMemory.writeMemory(0x1 + offset - romEndingOffset, data: UInt8((b & 0xFF00) >> 8));
				self.ppuMemory.writeMemory(0x2 + offset - romEndingOffset, data: UInt8((b & 0xFF0000) >> 16));
				self.ppuMemory.writeMemory(0x3 + offset - romEndingOffset, data: UInt8((b & 0xFF000000) >> 24));
                
//                print(String(format: "Byte: 0x%8x", b));
//                print(String(format: "A: 0x%2x, B: 0x%2x, C: 0x%2x, D: 0x%2x", UInt8(b & 0xFF), UInt8((b & 0xFF00) >> 8), UInt8((b & 0xFF0000) >> 16), UInt8((b & 0xFF000000) >> 24)));

			} else {
				self.mainMemory.writeMemory(0x8000 + offset, data: UInt8(b & 0xFF));
				self.mainMemory.writeMemory(0x8001 + offset, data: UInt8((b & 0xFF00) >> 8));
				self.mainMemory.writeMemory(0x8002 + offset, data: UInt8((b & 0xFF0000) >> 16));
				self.mainMemory.writeMemory(0x8003 + offset, data: UInt8((b & 0xFF000000) >> 24));
				
//////                    print(String(format: "Byte: 0x%8x", b));
//                    print(String(format: "%d A: 0x%2x, B: 0x%2x, C: 0x%2x, D: 0x%2x", i, UInt8(b & 0xFF), UInt8((b & 0xFF00) >> 8), UInt8((b & 0xFF0000) >> 16), UInt8((b & 0xFF000000) >> 24)));
			}
            
			i += 1;
		}
		
		print("Memory initialized, wrote \(i * 4) bytes");
		
		return true;
	}
}
