//
//  APU.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 5/6/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class APU {
	
	// MARK: - Class declarations
	
	private class APURegister {
		private let lengthTable: [UInt8] = [0x0A, 0xFE, 0x14, 0x02, 0x28, 0x04, 0x50, 0x06, 0xA0, 0x08, 0x3C,
		                                    0x0A, 0x0E, 0x0C, 0x1A, 0x0E, 0x0C, 0x10, 0x18, 0x12, 0x30, 0x14,
		                                    0x60, 0x16, 0xC0, 0x18, 0x48, 0x1A, 0x10, 0x1C, 0x20, 0x1E];
		
		// Register 4
		var lengthCounter: UInt8 {
			didSet {
				self.wavelength = (self.wavelength & 0xF) | (UInt16(lengthCounter & 0x3) << 8);
				self.lengthCounterLoad = self.lengthTable[Int((lengthCounter >> 3) & 0x1F)];
			}
		}
		// 3 bits
		var wavelength: UInt16;
		// 5 bits
		var lengthCounterLoad: UInt8;
		
		var lengthCounterDisable: Bool;
		
		var timer: UInt16;
		
		init() {
			self.lengthCounter = 0;
			self.wavelength = 0;
			self.lengthCounterLoad = 0;
			
			self.timer = 0;
			
			self.lengthCounterDisable = true;
		}
		
		func stepLength() {
			if(!self.lengthCounterDisable && self.lengthCounterLoad > 0) {
				self.lengthCounterLoad -= 1;
			}
		}
	}
	
	private final class Square: APURegister {
		
		// Register 1
		var control: UInt8 {
			didSet {
				self.volume = control & 0xF;
				self.envelopeDisable = control & 0x10 == 0x10;
				self.lengthCounterDisable = control & 0x20 == 0x20;
				self.dutyCycleType = (control >> 6) & 0x3;
			}
		}
		// 4 bits
		var volume: UInt8;
		var envelopeDisable: Bool;
		// 2 bits
		var dutyCycleType: UInt8;
		
		// Register 2
		var sweep: UInt8 {
			didSet {
				self.rightShiftAmount = sweep & 0x7;
				self.decreaseWavelength = sweep & 0x8 == 0x8;
				self.sweepUpdateRate = (sweep >> 4) & 0x7;
				self.sweepEnable = sweep & 0x80 == 0x80;
			}
		}
		// 3 bits
		var rightShiftAmount: UInt8;
		var decreaseWavelength: Bool;
		// 3 bits
		var sweepUpdateRate: UInt8;
		var sweepEnable: Bool;
		
		// Register 3
		var wavelengthLow: UInt8 {
			didSet {
				self.wavelength = (self.wavelength & 0x30) | UInt16(wavelengthLow);
			}
		}
		
		override init() {
			self.control = 0;
			self.volume = 0;
			self.envelopeDisable = false;
			self.dutyCycleType = 0;
			
			self.sweep = 0;
			self.rightShiftAmount = 0;
			self.decreaseWavelength = false;
			self.sweepUpdateRate = 0;
			self.sweepEnable = false;
			
			self.wavelengthLow = 0;
		}
		
		func stepSweep() {
			
		}
		
		func stepEnvelope() {
			
		}
	}
	
	private final class Triangle: APURegister {
		
		// Register 1
		var control: UInt8 {
			didSet {
				self.linearCounterLoad = control & 0x7F;
				self.linearCounter = self.linearCounterLoad;
				self.lengthCounterDisable = control & 0x80 == 0x80;
			}
		}
		// 7 bits
		var linearCounterLoad: UInt8;
		
		// Register 2 not used
		
		// Register 3
		var wavelengthLow: UInt8 {
			didSet {
				self.wavelength = (self.wavelength & 0x30) | UInt16(wavelengthLow);
			}
		}
		
		override var lengthCounter: UInt8 {
			didSet {
				self.wavelength = (self.wavelength & 0xF) | (UInt16(lengthCounter & 0x3) << 8);
				self.lengthCounterLoad = self.lengthTable[Int((lengthCounter >> 3) & 0x1F)];
				self.linearHalt = true;
			}
		}
		
		var linearCounter: UInt8;
		var linearHalt: Bool;
		
		var triangleGenerator: UInt8;
		var triangleIncreasing: Bool;
		
		override init() {
			self.control = 0;
			self.linearCounterLoad = 0;
			
			self.wavelengthLow = 0;
			
			self.linearCounter = 0;
			self.linearHalt = false;
			
			self.triangleGenerator = 0;
			self.triangleIncreasing = true;
		}
		
		func stepLinear() {
			if(self.linearHalt) {
				self.linearCounter = self.linearCounterLoad;
			} else if(self.linearCounter != 0) {
				self.linearCounter -= 1;
			}
			
			if(!self.lengthCounterDisable) {
				self.linearHalt = false;
			}
		}
		
		func stepTriangleGenerator() {
			if(self.triangleGenerator == 0) {
				self.triangleIncreasing = true;
			} else if(self.triangleGenerator == 0xF) {
				self.triangleIncreasing = false;
			}
			
			if(self.triangleIncreasing) {
				self.triangleGenerator += 1;
			} else {
				self.triangleGenerator -= 1;
			}
		}
		
		func stepTimer() {
			if(self.timer == 0) {
				self.timer = self.wavelength;
				stepTriangleGenerator();
			} else {
				self.timer += 1;
			}
		}
	}
	
	private final class Noise: APURegister {
		
		var control: UInt8 {
			didSet {
				self.volume = control & 0xF;
				self.envelopeDisable = control & 0x10 == 0x10;
				self.lengthCounterDisable = control & 0x20 == 0x20;
				self.dutyCycleType = (control >> 6) & 0x3;
			}
		}
		// 4 bits
		var volume: UInt8;
		var envelopeDisable: Bool;
		var dutyCycleType: UInt8;
		
		// Register 2 unused
		
		// Register 3
		var period: UInt8 {
			didSet {
				self.sampleRate = period & 0xF;
				self.randomNumberGeneration = period & 0x80 == 0x80;
			}
		}
		// 4 bits
		var sampleRate: UInt8;
		// 3 unused bits
		var randomNumberGeneration: Bool;
		
		// 3 unused bits in register 4 (msbWavelength)
		
		override init() {
			self.control = 0;
			self.volume = 0;
			self.envelopeDisable = false;
			self.dutyCycleType = 0;
			
			self.period = 0;
			self.sampleRate = 0;
			self.randomNumberGeneration = false;
		}
		
		func stepEnvelope() {
			
		}
	}
	
	// MARK: - APU Registers
	
	private var dmcControl: UInt8 {
		didSet {
			self.dmcFrequencyControl = dmcControl & 0xF;
			self.dmcLoop = dmcControl & 0x40 == 0x40;
			self.dmcGenerateIRQ = dmcControl & 0x80 == 0x80;
		}
	}
	
	private var dmcFrequencyControl: UInt8;
	private var dmcLoop: Bool;
	private var dmcGenerateIRQ: Bool;
	
	private var deltaCounterLoad: UInt8 {
		didSet {
			// TODO: Handle LSB of DAC
			self.dmcDeltaCounter = (deltaCounterLoad >> 1) & 0x3F;
		}
	}
	
	private var dmcDeltaCounter: UInt8;
	
	private var dmcAddressLoad: UInt8 {
		didSet {
			// TODO: Handle DMC address load
		}
	}
	
	private var dmcLength: UInt8 {
		didSet {
			// TODO: Handle DMC length
		}
	}
	
	private var control: UInt8 {
		didSet {
			self.square1Enable = control & 0x1 == 0x1;
			self.square2Enable = control & 0x2 == 0x2;
			self.triangleEnable = control & 0x4 == 0x4;
			self.noiseEnable = control & 0x8 == 0x8;
			
			if(!self.square1Enable) {
				self.square1.lengthCounterLoad = 0;
			}
			
			if(!self.square2Enable) {
				self.square2.lengthCounterLoad = 0;
			}
			
			if(!self.triangleEnable) {
				self.triangle.lengthCounterLoad = 0;
			}
			
			if(!self.noiseEnable) {
				self.noise.lengthCounterLoad = 0;
			}
			
			// TODO: Handle disabling DMC playback if bit 4 is clear
		}
	}
	
	private var square1Enable: Bool;
	private var square2Enable: Bool;
	private var triangleEnable: Bool;
	private var noiseEnable: Bool;
	
	
	private var timerControl: UInt8 {
		didSet {
			self.disableIRQ = timerControl & 0x40 == 0x40;
			self.framerateSwitch = timerControl & 0x80 == 0x80;
			
			if(self.framerateSwitch) {
				self.frameCount = 0;
				stepFrame();
			} else {
				self.frameCount = 4;
			}
		}
	}
	
	private var disableIRQ: Bool;
	
	/**
		If true, 5 frames occur in each frame counter cycle, otherwise 4
	*/
	private var framerateSwitch: Bool;
	
	// MARK: - APU Variables
	
	private let square1: Square;
	private let square2: Square;
	private let triangle: Triangle;
	private let noise: Noise;
	
	private var cycle: Int;
	private var frameCount: Int;
	
	init() {
		self.dmcControl = 0;
		self.dmcFrequencyControl = 0;
		self.dmcLoop = false;
		self.dmcGenerateIRQ = false;
		
		self.deltaCounterLoad = 0;
		self.dmcDeltaCounter = 0;
		
		self.dmcAddressLoad = 0;
		
		self.dmcLength = 0;
		
		self.control = 0;
		self.square1Enable = false;
		self.square2Enable = false;
		self.triangleEnable = false;
		self.noiseEnable = false;
		
		self.timerControl = 0;
		self.disableIRQ = false;
		self.framerateSwitch = false;
		
		self.square1 = Square();
		self.square2 = Square();
		self.triangle = Triangle();
		self.noise = Noise();
		
		self.cycle = 0;
		self.frameCount = 4;
	}
	
	// MARK: - APU Functions
	
	func step() {
		// 1789773 / 239.9963124
		if(self.cycle > 7457) {
			self.cycle = 0;
			stepFrame();
		} else {
			self.cycle += 1;
		}
	}
	
	private func stepFrame() {
		if(self.framerateSwitch) {
			self.frameCount = (self.frameCount + 1) % 5;
		} else {
			self.frameCount = (self.frameCount + 1) % 4;
		}
		
		switch(self.frameCount) {
			case 0, 2:
				stepEnvelope();
			case 1, 3:
				stepEnvelope();
				
				stepSweep();
				
				stepLength();
				break;
			case 4:
				break;
			default:
				break;
		}
	}
	
	private func stepEnvelope() {
		// Increment envelope (Square and Noise)
		self.square1.stepEnvelope();
		self.square2.stepEnvelope();
		self.triangle.stepLinear();
		self.noise.stepEnvelope();
	}
	
	private func stepSweep() {
		// Increment frequency sweep (Square)
		self.square1.stepSweep();
		self.square2.stepSweep();
	}
	
	private func stepLength() {
		// Increment length counters (all)
		self.square1.stepLength();
		self.square2.stepLength();
		self.triangle.stepLength();
		self.noise.stepLength();
	}
	
	// MARK: - APU Register Access
	
	func cpuWrite(address: Int, data: UInt8) {
		switch(address) {
			case 0x4000:
				self.square1.control = data;
			case 0x4001:
				self.square1.sweep = data;
			case 0x4002:
				self.square1.wavelengthLow = data;
			case 0x4003:
				if(self.square1Enable) {
					self.square1.lengthCounter = data;
				}
			case 0x4004:
				self.square2.control = data;
			case 0x4005:
				self.square2.sweep = data;
			case 0x4006:
				self.square2.wavelengthLow = data;
			case 0x4007:
				if(self.square2Enable) {
					self.square2.lengthCounter = data;
				}
			case 0x4008:
				self.triangle.control = data;
			case 0x4009:
				break;
			case 0x400A:
				self.triangle.wavelengthLow = data;
			case 0x400B:
				if(self.triangleEnable) {
					self.triangle.lengthCounter = data;
				}
			case 0x400C:
				self.noise.control = data;
			case 0x400D:
				break;
			case 0x400E:
				self.noise.period = data;
			case 0x400F:
				if(self.noiseEnable) {
					self.noise.lengthCounter = data;
				}
			case 0x4010:
				self.dmcControl = data;
			case 0x4011:
				self.deltaCounterLoad = data;
			case 0x4012:
				self.dmcAddressLoad = data;
			case 0x4013:
				self.dmcLength = data;
 			case 0x4015:
				self.control = data;
			case 0x4017:
				self.timerControl = data;
			default:
				break;
		}
	}
	
	func cpuRead(address: Int) -> UInt8 {
		if(address == 0x4015) {
			var temp: UInt8 = (self.square1.lengthCounterLoad == 0 || !self.square1Enable) ? 0 : 1;
			temp |= (self.square2.lengthCounterLoad == 0 || !self.square2Enable) ? 0 : 0x2;
			temp |= (self.triangle.lengthCounterLoad == 0 || !self.triangleEnable) ? 0 : 0x4;
			temp |= (self.noise.lengthCounterLoad == 0 || !self.noiseEnable) ? 0 : 0x8;
			
			// TODO: Return DMC length counter status
			// TODO: Return frame IRQ status
			// TODO: Return DMC IRQ status
			
			return temp;
		} else {
//			print(String(format: "Invalid read at %x", address));
		}
		
		return 0;
	}
}