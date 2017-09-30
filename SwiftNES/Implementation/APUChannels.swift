//
//  APUChannels.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/9/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

class APURegister {
	
	let lengthTable: [UInt8] = [0x0A, 0xFE, 0x14, 0x02, 0x28, 0x04, 0x50, 0x06, 0xA0, 0x08, 0x3C,
	                            0x0A, 0x0E, 0x0C, 0x1A, 0x0E, 0x0C, 0x10, 0x18, 0x12, 0x30, 0x14,
	                            0x60, 0x16, 0xC0, 0x18, 0x48, 0x1A, 0x10, 0x1C, 0x20, 0x1E]
	
	let dutyTable: [[UInt8]] = [[0, 1, 0, 0, 0, 0, 0, 0], [0, 1, 1, 0, 0, 0, 0, 0], [0, 1, 1, 1, 1, 0, 0, 0], [1, 0, 0, 1, 1, 1, 1, 1]]
	
	let noiseTable: [UInt16] = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
	
	// Register 4
	var lengthCounter: UInt8 {
		didSet {
			wavelength = (wavelength & 0xFF) | (UInt16(lengthCounter & 0x7) << 8)
			lengthCounterLoad = lengthTable[Int((lengthCounter >> 3) & 0x1F)]
		}
	}
	// 3 bits
	var wavelength: UInt16
	// 5 bits
	var lengthCounterLoad: UInt8
	
	var lengthCounterDisable: Bool
	
	var timer: UInt16
	
	init() {
		lengthCounter = 0
		wavelength = 0
		lengthCounterLoad = 0
		
		timer = 0
		
		lengthCounterDisable = true
	}
	
	func stepLength() {
		if !lengthCounterDisable && lengthCounterLoad > 0 {
			lengthCounterLoad -= 1
		}
	}
}

final class Square: APURegister {
	
	// Register 1
	var control: UInt8 {
		didSet {
			envelopeDisable = control & 0x10 == 0x10
			lengthCounterDisable = control & 0x20 == 0x20
			dutyCycleType = (control >> 6) & 0x3
			
			envelopePeriod = control & 0xF
			constantVolume = envelopePeriod
			
			envelopeShouldUpdate = true
		}
	}
	// 4 bits
	var volume: UInt8
	var envelopeDisable: Bool
	// 2 bits
	var dutyCycleType: UInt8
	
	// Register 2
	var sweep: UInt8 {
		didSet {
			sweepShift = sweep & 0x7
			decreaseWavelength = sweep & 0x8 == 0x8
			sweepUpdateRate = (sweep >> 4) & 0x7
			sweepEnable = sweep & 0x80 == 0x80
			
			sweepShouldUpdate = true
		}
	}
	// 3 bits
	var sweepShift: UInt8
	var decreaseWavelength: Bool
	// 3 bits
	var sweepUpdateRate: UInt8
	var sweepEnable: Bool
	
	// Register 3
	var wavelengthLow: UInt8 {
		didSet {
			wavelength = (wavelength & 0xFF00) | UInt16(wavelengthLow)
		}
	}
	
	// Register 4
	override var lengthCounter: UInt8 {
		didSet {
			wavelength = (wavelength & 0xFF) | (UInt16(lengthCounter & 0x7) << 8)
			lengthCounterLoad = lengthTable[Int((lengthCounter >> 3) & 0x1F)]
			dutyIndex = 0
			envelopeShouldUpdate = true
		}
	}
	
	private var channel2: Bool
	
	var sweepShouldUpdate: Bool
	var sweepValue: UInt8
	var targetWavelength: UInt16
	
	var dutyIndex: Int
	
	var envelopeShouldUpdate: Bool
	var envelopePeriod: UInt8
	var envelopeVolume: UInt8
	var constantVolume: UInt8
	var envelopeValue: UInt8
	
	override convenience init() {
		self.init(isChannel2: false)
	}
	
	init(isChannel2: Bool) {
		control = 0
		volume = 0
		envelopeDisable = false
		dutyCycleType = 0
		
		sweep = 0
		sweepShift = 0
		decreaseWavelength = false
		sweepUpdateRate = 0
		sweepEnable = false
		
		wavelengthLow = 0
		
		channel2 = isChannel2
		
		sweepShouldUpdate = false
		sweepValue = 0
		targetWavelength = 0
		
		dutyIndex = 0
		
		envelopeShouldUpdate = false
		envelopePeriod = 0
		envelopeVolume = 0
		constantVolume = 0
		envelopeValue = 0
		
		super.init()
	}
	
	func stepSweep() {
		if sweepShouldUpdate {
			if sweepEnable && sweepValue == 0 {
				sweepUpdate()
			}
			
			sweepValue = sweepUpdateRate
			sweepShouldUpdate = false
		} else if sweepValue > 0 {
			sweepValue -= 1
		} else {
			if sweepEnable {
				sweepUpdate()
			}
			
			sweepValue = sweepUpdateRate
		}
	}
	
	private func sweepUpdate() {
		let delta = wavelength >> UInt16(sweepShift)
		
		if decreaseWavelength {
			targetWavelength = wavelength - delta
			
			if !channel2 {
				targetWavelength += 1
			}
		} else {
			targetWavelength = wavelength + delta
		}
		
		if sweepEnable && sweepShift != 0 && wavelength > 7 && targetWavelength < 0x800 {
			wavelength = targetWavelength
		}
	}
	
	func stepTimer() {
		if timer == 0 {
			timer = wavelength
			dutyIndex = (dutyIndex + 1) % 8
		} else {
			timer -= 1
		}
	}
	
	func stepEnvelope() {
		if envelopeShouldUpdate {
			envelopeVolume = 0xF
			envelopeValue = envelopePeriod
			envelopeShouldUpdate = false
		} else if envelopeValue > 0 {
			envelopeValue -= 1
		} else {
			if envelopeVolume > 0 {
				envelopeVolume -= 1
			} else if lengthCounterDisable {
				envelopeVolume = 0xF
			}
			
			envelopeValue = envelopePeriod
		}
	}
	
	func output() -> UInt8 {
		if lengthCounterLoad == 0 || dutyTable[Int(dutyCycleType)][dutyIndex] == 0 || wavelength < 8 || targetWavelength > 0x7FF {
			return 0
		}
		
		if(!envelopeDisable) {
			return envelopeVolume
		}
		
		return constantVolume
	}
}

final class Triangle: APURegister {
	
	// Register 1
	var control: UInt8 {
		didSet {
			linearCounterLoad = control & 0x7F
			lengthCounterDisable = control & 0x80 == 0x80
		}
	}
	// 7 bits
	var linearCounterLoad: UInt8
	
	// Register 2 not used
	
	// Register 3
	var wavelengthLow: UInt8 {
		didSet {
			wavelength = (wavelength & 0xFF00) | UInt16(wavelengthLow)
		}
	}
	
	override var lengthCounter: UInt8 {
		didSet {
			wavelength = (wavelength & 0xFF) | (UInt16(lengthCounter & 0x7) << 8)
			lengthCounterLoad = lengthTable[Int((lengthCounter >> 3) & 0x1F)]
			timer = wavelength
			linearReload = true
		}
	}
	
	var linearCounter: UInt8
	var linearReload: Bool
	
	var triangleGenerator: UInt8
	var triangleIncreasing: Bool
	
	override init() {
		control = 0
		linearCounterLoad = 0
		
		wavelengthLow = 0
		
		linearCounter = 0
		linearReload = false
		
		triangleGenerator = 0
		triangleIncreasing = true
	}
	
	func stepLinear() {
		if linearReload {
			linearCounter = linearCounterLoad
		} else if linearCounter > 0 {
			linearCounter -= 1
		}
		
		if !lengthCounterDisable {
			linearReload = false
		}
	}
	
	func stepTriangleGenerator() {
		if triangleGenerator == 0 && !triangleIncreasing {
			triangleIncreasing = true
			return
		} else if triangleGenerator == 0xF && triangleIncreasing {
			triangleIncreasing = false
			return
		}
		
		if triangleIncreasing {
			triangleGenerator += 1
		} else {
			triangleGenerator -= 1
		}
	}
	
	func stepTimer() {
		if timer == 0 {
			timer = wavelength
			if lengthCounterLoad > 0 && linearCounter > 0 {
				stepTriangleGenerator()
			}
		} else {
			timer -= 1
		}
	}
	
	func output() -> Double {
		if lengthCounterLoad == 0 || linearCounter == 0 {
			return 0
		}
		
		if wavelength == 0 || wavelength == 1 {
			return 7.5
		}
		
		return Double(triangleGenerator)
	}
}

final class Noise: APURegister {
	
	var control: UInt8 {
		didSet {
			constantVolume = control & 0xF
			envelopePeriod = constantVolume
			
			envelopeDisable = control & 0x10 == 0x10
			lengthCounterDisable = control & 0x20 == 0x20
			dutyCycleType = (control >> 6) & 0x3
		}
	}
	// 4 bits
	var constantVolume: UInt8
	var envelopeDisable: Bool
	var dutyCycleType: UInt8
	
	// Register 2 unused
	
	// Register 3
	var period: UInt8 {
		didSet {
			sampleRate = noiseTable[Int(period & 0xF)]
			randomNumberGeneration = period & 0x80 == 0x80
		}
	}
	// 4 bits
	var sampleRate: UInt16
	// 3 unused bits
	var randomNumberGeneration: Bool
	
	// 3 unused bits in register 4 (msbWavelength)
	override var lengthCounter: UInt8 {
		didSet {
			lengthCounterLoad = lengthTable[Int((lengthCounter >> 3) & 0x1F)]
			envelopeShouldUpdate = true
		}
	}
	
	var shiftRegister: UInt16
	
	var envelopeShouldUpdate: Bool
	var envelopePeriod: UInt8
	var envelopeVolume: UInt8
	var envelopeValue: UInt8
	
	override init() {
		control = 0
		constantVolume = 0
		envelopeDisable = false
		dutyCycleType = 0
		
		period = 0
		sampleRate = 0
		randomNumberGeneration = false
		
		shiftRegister = 1
		
		envelopeShouldUpdate = false
		envelopePeriod = 0
		envelopeVolume = 0
		envelopeValue = 0
	}
	
	func stepTimer() {
		if timer == 0 {
			timer = sampleRate
			
			let shift: UInt16 = randomNumberGeneration ? 6 : 1
			
			let bit0 = shiftRegister & 0x1
			let bit1 = (shiftRegister >> shift) & 0x1
			
			shiftRegister = shiftRegister >> 1
			shiftRegister |= (bit0 ^ bit1) << 14
		} else {
			timer -= 1
		}
	}
	
	func stepEnvelope() {
		if envelopeShouldUpdate {
			envelopeVolume = 0xF
			envelopeValue = envelopePeriod
			envelopeShouldUpdate = false
		} else if envelopeValue > 0 {
			envelopeValue -= 1
		} else {
			if envelopeVolume > 0 {
				envelopeVolume -= 1
			} else if lengthCounterDisable {
				envelopeVolume = 0xF
			}
			
			envelopeValue = envelopePeriod
		}
	}
	
	func output() -> UInt8 {
		if lengthCounterLoad == 0 || shiftRegister & 0x1 == 1 {
			return 0
		}
		
		if !envelopeDisable {
			return envelopeVolume
		}
		
		return constantVolume
	}
}

final class DMC {
	let rateTable: [UInt16] = [428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 84, 72, 54]
	
	var control: UInt8 {
		didSet {
			irqEnabled = control & 0x80 == 0x80
			
			if !irqEnabled {
				dmcIRQ = false
			}
			
			loopEnabled = control & 0x40 == 0x40
			rate = rateTable[Int(control & 0xF)]
			timer = rate
		}
	}
	
	var irqEnabled: Bool
	var loopEnabled: Bool
	var rate: UInt16
	
	var directLoad: UInt8 {
		didSet {
			volume = directLoad & 0x7F
		}
	}
	
	var address: UInt8 {
		didSet {
			currentAddress = 0xC000 | (UInt16(address) << 6)
		}
	}
	
	private var currentAddress: UInt16
	
	var sampleLength: UInt8 {
		didSet {
//			self.sampleLengthRemaining = (UInt16(sampleLength) << 4) | 1
		}
	}
	
	var sampleLengthRemaining: UInt16
	
	private var timer: UInt16
	private var volume: UInt8
	var dmcIRQ: Bool
	
	private var shiftCount: Int
	
	var buffer: UInt8
	
	let memory: Memory
	var cpu: CPU?
	
	init(memory: Memory) {
		self.memory = memory
		cpu = nil
		
		control = 0
		irqEnabled = false
		loopEnabled = false
		rate = 0
		
		directLoad = 0
		
		address = 0
		currentAddress = 0
		
		sampleLength = 0
		sampleLengthRemaining = 0
		
		timer = 0
		volume = 0
		dmcIRQ = false
		shiftCount = 0
		
		buffer = 0
	}
	
	func restart() {
		currentAddress = 0xC000 | (UInt16(address) << 6)
		sampleLengthRemaining = (UInt16(sampleLength) << 4) | 1
	}
	
	func stepTimer() {
		stepReader()
		
		if timer == 0 {
			timer = rate
			stepShifter()
		} else {
			timer -= 1
		}
	}
	
	func stepReader() {
		if sampleLengthRemaining > 0 && shiftCount == 0 {
			// TODO: Delay CPU by 4 cycles (varies, see http://forums.nesdev.com/viewtopic.php?p=62690#p62690)
			cpu?.startDMCTransfer()
			buffer = memory.readMemory(currentAddress)
			
			shiftCount = 8
			
			currentAddress += 1
			
			if currentAddress > 0xFFFF {
				currentAddress = 0x8000
			}
			
			sampleLengthRemaining -= 1
			
			if sampleLengthRemaining == 0 {
				if loopEnabled {
					restart()
				} else if irqEnabled {
					dmcIRQ = true
				}
			}
		}
	}
	
	func stepShifter() {
		if shiftCount == 0 {
			return
		}
		
		if buffer & 0x1 == 0x1 {
			if volume < 126 {
				volume += 2
			}
		} else {
			if volume > 1 {
				volume -= 2
			}
		}
		
		buffer = buffer >> 1
		shiftCount -= 1
	}
	
	func output() -> UInt8 {
		return volume
	}
}
