//
//  FileIO.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation
//import Cocoa

final class FileIO: NSObject {
	
	let mainMemory: CPUMemory
	let ppuMemory: PPUMemory
	
	init(mainMemory: CPUMemory, ppuMemory: PPUMemory) {
		self.mainMemory = mainMemory
		self.ppuMemory = ppuMemory
	}
	
	func loadFile(_ path: String) -> Bool {
		let data = FileManager.default.contents(atPath: path)
		
		if(data == nil) {
			print("File failed to load")
			return false
		}
		
		let count = data!.count / MemoryLayout<UInt8>.size
		var bytes = [UInt8](repeating: 0, count: count)
		
		(data as NSData?)?.getBytes(&bytes, length: data!.count * MemoryLayout<UInt8>.size)
		
		// NES(escape) in little endian
		if(bytes[0] != 0x4E || bytes[1] != 0x45 || bytes[2] != 0x53 || bytes[3] != 0x1A) {
			print("Invalid input file, does not contain NES header")
			return false
		}
		
		let prgBanks = bytes[4]
		
		if(prgBanks == 1) {
			mainMemory.mirrorPRGROM = true
		}
		
		var chrBanks = bytes[5]
		let misc = bytes[6]
		
		let verticalMirroring = misc & 0x1 == 1
		
		if(verticalMirroring) {
			ppuMemory.nametableMirroring = .vertical
		} else {
			ppuMemory.nametableMirroring = .horizontal
		}
		
		// Battery Backed RAM at $6000 - $7FFF
		let batteryBackedRAM = misc & 0x2 == 1
		
		// 512-byte trainer at $7000-$71FF
		let trainer = misc & 0x4 == 1
		
		let fourScreenVRAM = misc & 0x8 == 1
		
		let romMapperLower = (misc & 0xF0) >> 4
		
		let misc2 = bytes[7]
		
		// This cartridge is for a Nintendo VS System
		let nesVSSystem = misc2 & 0x1 == 1
		
		let romMapperUpper = (misc2 & 0xF0) >> 4
		
		let romMapper = Int((romMapperUpper << 4) + romMapperLower)
		
		let ramBanks = bytes[8]
		
		let NTSC = bytes[9] == 0
		
		print("PRG Banks: \(prgBanks), CHR Banks: \(chrBanks)")
		print("Vertical Mirroring: \(verticalMirroring), Battery Backed RAM: \(batteryBackedRAM)")
		print("Trainer: \(trainer), Four Screen VRAM: \(fourScreenVRAM), NES VS System: \(nesVSSystem)")
		print("ROM Mapper \(romMapper), RAM Banks: \(ramBanks), NTSC: \(NTSC)")
		
		let prgOffset = Int(prgBanks) * 0x4000
		
		mainMemory.banks = [UInt8](repeating: 0, count: prgOffset)
		ppuMemory.banks = [UInt8](repeating: 0, count: Int(chrBanks) * 0x2000)
		
		if !setMapper(romMapper, cpuMemory: mainMemory, ppuMemory: ppuMemory) {
			return false
		}
		
		for i in 0 ..< prgOffset {
			mainMemory.banks[i] = bytes[16 + i]
		}
		
		for i in 0 ..< Int(chrBanks) * 0x2000 {
			ppuMemory.banks[i] = bytes[prgOffset + 16 + i]
		}
		
		if chrBanks == 0 {
			// Use CHR RAM
			chrBanks = 1
			ppuMemory.banks = [UInt8](repeating: 0, count: 0x2000)
		}

		mainMemory.mapper.chrBankCount = chrBanks
		mainMemory.mapper.prgBankCount = prgBanks
		
		print("Memory initialized")
		
		return true
	}
	
	func setMapper(_ mapperNumber: Int, cpuMemory: CPUMemory, ppuMemory: PPUMemory) -> Bool {
		var mapper = cpuMemory.mapper
		
		switch mapperNumber {
			case 0:
				// Do nothing, Mapper 0 is default
				break
			case 1:
				mapper = Mapper1()
			case 2:
				mapper = Mapper2()
			case 3:
				mapper = Mapper3()
			case 4:
				mapper = Mapper4()
			case 7:
				mapper = Mapper7()
				ppuMemory.nametableMirroring = .oneScreen
			case 9:
				mapper = Mapper9()
			case 11:
				mapper = Mapper11()
			default:
				print("Unknown mapper \(mapperNumber)")
				return false
		}
		
		cpuMemory.setMapper(mapper)
		ppuMemory.setMapper(mapper)
		
		return true
	}
}
