//
//  Memory.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

class Memory {
	/* Main Memory
	-- $10000 --
	 PRG-ROM Upper Bank
	-- $C000 --
	 PRG-ROM Lower Bank
	-- $8000 --
	 SRAM
	-- $6000 --
	 Expansion ROM
	-- $4020 --
	 I/O Registers
	-- $4000 --
	 Mirrors $2000 - $2007
	-- $2008 --
	 I/O Registers
	-- $2000 --
	 Mirrors $0000 - $07FF
	-- $0800 --
	 RAM
	-- $0200 --
	 Stack
	-- $0100 --
	 Zero Page
	-- $0000 --
	*/
	
	enum NametableMirroringType {
		case vertical
		
		case horizontal
		
		case oneScreen
		
		case fourScreen
	}
	
	var mapper: Mapper
	
	var banks: [UInt8]
	
	var mirrorPRGROM = false
	
	init(mapper: Mapper) {
		// Dummy initialization
		banks = [UInt8](repeating: 0, count: 1)
		self.mapper = mapper
		setMapper(mapper)
	}
	
	func readMemory(_ address: Int) -> UInt8 {
		return 0
	}
	
	final func readTwoBytesMemory(_ address: Int) -> UInt16 {
		return UInt16(readMemory(address + 1)) << 8 | UInt16(readMemory(address))
	}
	
	func writeMemory(_ address: Int, data: UInt8) {
		fatalError("writeMemory function not overriden")
	}
	
    final func writeTwoBytesMemory(_ address: Int, data: UInt16) {
        writeMemory(address, data: UInt8(data & 0xFF))
        writeMemory(address + 1, data: UInt8((data & 0xFF00) >> 8))
    }
	
	func setMapper(_ mapper: Mapper) {
		fatalError("setMapper function not overriden")
	}
}

final class PPUMemory: Memory {
	
	/* -- $4000
	Empty
	-- $3F20 --
	Sprite Palette
	-- $3F10 --
	Image Palette
	-- $3F00 --
	Empty
	-- $3000 --
	Attribute Table 3
	-- $2FC0 --
	Name Table 3 (32x30 tiles)
	-- $2C00 --
	Attribute Table 2
	-- $2BC0 --
	Name Table 2 (32x30 tiles)
	-- $2800 --
	Attribute Table 1
	-- $27C0 --
	Name Table 1 (32x30 tiles)
	-- $2400 --
	Attribute Table 0
	-- $23C0 --
	Name Table 0 (32x30 tiles)
	-- $2000 --
	Pattern Table 1 (256x2x8, may be VROM)
	-- $1000 --
	Pattern Table 0 (256x2x8, may be VROM)
	-- $0000 --
	*/
	
	var nametable: [UInt8]
	
	var nametableMirroring: NametableMirroringType = .oneScreen
	var oneScreenUpper: Bool
	
	private var previousAddress: Int
	var a12Timer: Int
	
	override init(mapper: Mapper) {
		nametable = [UInt8](repeating: 0, count: 0x2000)
		oneScreenUpper = false
		
		previousAddress = 0
		a12Timer = 0
		super.init(mapper: mapper)
	}
	
	final override func setMapper(_ mapper: Mapper) {
		mapper.ppuMemory = self
		self.mapper = mapper
	}
	
	final override func readMemory(_ address: Int) -> UInt8 {
		var address = address % 0x4000
		
		if address & 0x1000 == 0x1000 && previousAddress & 0x1000 == 0 {
			if a12Timer == 0 {
				mapper.step()
			}
			a12Timer = 16
		}
		
		previousAddress = address
		
		if address < 0x2000 {
			return mapper.read(address)
		} else if (address >= 0x2000) && (address < 0x3000) {
			if nametableMirroring == .oneScreen {
				address = 0x2000 | (address % 0x400)
				if oneScreenUpper {
					address += 0x400
				}
			} else if nametableMirroring == .horizontal {
				if address >= 0x2C00 {
					address -= 0x800
				} else if address >= 0x2400 {
					address -= 0x400
				}
			} else if nametableMirroring == .vertical {
				if address >= 0x2800 {
					address -= 0x800
				}
			} else {
				print("ERROR: Nametable mirroring type not implemented")
			}
		} else if (address > 0x2FFF) && (address < 0x3F00) {
			address -= 0x1000
		}
		
		return nametable[address - 0x2000]
	}
	
	final override func writeMemory(_ address: Int, data: UInt8) {
		var address = address % 0x4000
		
		if address & 0x1000 == 0x1000 && previousAddress & 0x1000 == 0 {
			if a12Timer == 0 {
				mapper.step()
			}
			a12Timer = 16
		}
		
		previousAddress = address
		
		if address < 0x2000 {
			mapper.write(address, data: data)
			return
		} else if (address >= 0x2000) && (address < 0x3000) {
			if nametableMirroring == .oneScreen {
				address = 0x2000 | (address % 0x400)
				if oneScreenUpper {
					address += 0x400
				}
			} else if nametableMirroring == .horizontal {
				if address >= 0x2C00 {
					address -= 0x800
				} else if address >= 0x2400 {
					address -= 0x400
				}
			} else if nametableMirroring == .vertical {
				if address >= 0x2800 {
					address -= 0x800
				}
			} else {
				print("ERROR: Nametable mirroring type not implemented")
			}
		} else if (address > 0x2FFF) && (address < 0x3F00) {
			address -= 0x1000
		} else if address >= 0x3F10 {
			address = 0x3F00 + address % 0x20
			
			if (address >= 0x3F10) && (address < 0x3F20) && (address & 0x3 == 0) {
				address -= 0x10
			}
		}
		
		nametable[address - 0x2000] = data
	}
	
	func readPaletteMemory(_ address: Int) -> UInt8 {
		var address = address % 0x20
		
		if address >= 0x10 && address < 0x20 && address & 0x3 == 0 {
			address -= 0x10
		}
		
		return nametable[0x1F00 + address]
	}
	
	
	func dumpMemory() {
		let logger = Logger(path: "/Users/adam/memory.dump")
		logger.dumpMemory(banks)
		logger.endLogging()
	}
}

final class CPUMemory: Memory {
	/* Main Memory
	-- $10000 --
	PRG-ROM Upper Bank
	-- $C000 --
	PRG-ROM Lower Bank
	-- $8000 --
	SRAM
	-- $6000 --
	Expansion ROM
	-- $4020 --
	I/O Registers
	-- $4000 --
	Mirrors $2000 - $2007
	-- $2008 --
	I/O Registers
	-- $2000 --
	Mirrors $0000 - $07FF
	-- $0800 --
	RAM
	-- $0200 --
	Stack
	-- $0100 --
	Zero Page
	-- $0000 --
	*/
	
	var ram: [UInt8]
	
	var sram: [UInt8]
	
	var ppu: PPU?
	var apu: APU?
	var controllerIO: ControllerIO?
	
	override init(mapper: Mapper) {
		ram = [UInt8](repeating: 0, count: 0x800)
		sram = [UInt8](repeating: 0, count: 0x2000)
		
		super.init(mapper: mapper)
	}
	
	final override func setMapper(_ mapper: Mapper) {
		mapper.cpuMemory = self
		self.mapper = mapper
	}
	
	final override func readMemory(_ address: Int) -> UInt8 {
		if address < 0x2000 {
			return ram[address % 0x800]
		} else if address < 0x4000 {
			guard let ppu = ppu else {
				fatalError("PPU does not exist for memory read")
			}

			switch address % 8 {
			case 0:
				return ppu.readWriteOnlyRegister()
			case 1:
				return ppu.readWriteOnlyRegister()
			case 2:
				return ppu.readPPUSTATUS()
			case 3:
				return ppu.readWriteOnlyRegister()
			case 4:
				return ppu.readOAMDATA()
			case 5:
				return ppu.readWriteOnlyRegister()
			case 6:
				return ppu.readWriteOnlyRegister()
			case 7:
				return ppu.readPPUDATA()
			default: break
			}
		} else if address == 0x4016 {
			return controllerIO!.readState()
		} else if address == 0x4017 {
			// TODO: Add second controller support
			return 0x40
		} else if address > 0x3FFF && address < 0x4018 {
			guard let apu = apu else {
				fatalError("APU does not exist for memory read")
			}

			return apu.cpuRead(address)
		} else if mirrorPRGROM && address >= 0xC000 {
			return mapper.read(address - 0x4000)
		}
		
		return mapper.read(address)
	}
	
	final override func writeMemory(_ address: Int, data: UInt8) {
		var address = address
		
		if address < 0x2000 {
			ram[address % 0x800] = data
			return
		} else if address < 0x4000 {
			ppu?.cpuWrite(address % 8, data: data)
			return
		} else if address == 0x4014 {
			ppu?.OAMDMA = data
			return
		} else if address == 0x4016 {
			controllerIO?.strobeHigh = data & 0x1 == 1
			return
		} else if address > 0x3FFF && address < 0x4018 {
			apu?.cpuWrite(address, data: data)
			return
		} else if mirrorPRGROM && address >= 0xC000 {
			address = address - 0x4000
		}
		
		mapper.write(address, data: data)
	}
}
