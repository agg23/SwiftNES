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
		// Register 4
		var lengthCounter: UInt8 {
			didSet {
				self.wavelengthHigh = lengthCounter & 0x3;
				self.lengthCounterLoad = (lengthCounter >> 3) & 0x1F;
			}
		}
		// 3 bits
		var wavelengthHigh: UInt8;
		// 5 bits
		var lengthCounterLoad: UInt8;
		
		init() {
			self.lengthCounter = 0;
			self.wavelengthHigh = 0;
			self.lengthCounterLoad = 0;
		}
		
		func stepLength() {
			
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
		var lengthCounterDisable: Bool;
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
		var wavelengthLow: UInt8;
		
		override init() {
			self.control = 0;
			self.volume = 0;
			self.envelopeDisable = false;
			self.lengthCounterDisable = false;
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
				self.lengthCounterClockDisable = control & 0x80 == 0x80;
			}
		}
		// 7 bits
		var linearCounterLoad: UInt8;
		var lengthCounterClockDisable: Bool;
		
		// Register 2 not used
		
		// Register 3
		var wavelengthLow: UInt8;
		
		override init() {
			self.control = 0;
			self.linearCounterLoad = 0;
			self.lengthCounterClockDisable = false;
			
			self.wavelengthLow = 0;
		}
		
		func stepLinear() {
			
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
		var lengthCounterDisable: Bool;
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
			self.lengthCounterDisable = false;
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
	
	private var transferPPU: UInt8 {
		didSet {
			// TODO: Handle 256 byte copy to $2004
		}
	}
	
	private var control: UInt8 {
		didSet {
			self.square1Enable = control & 0x1 == 0x1;
			self.square2Enable = control & 0x2 == 0x2;
			self.triangleEnable = control & 0x4 == 0x4;
			self.noiseEnable = control & 0x8 == 0x8;
			
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
		
		self.transferPPU = 0;
		
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
		
	}
	
	func stepFrame() {
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
	
	func stepEnvelope() {
		// Increment envelope (Square and Noise)
		self.square1.stepEnvelope();
		self.square2.stepEnvelope();
		self.triangle.stepLinear();
		self.noise.stepEnvelope();
	}
	
	func stepSweep() {
		// Increment frequency sweep (Square)
		self.square1.stepSweep();
		self.square2.stepSweep();
	}
	
	func stepLength() {
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
				self.square1.lengthCounter = data;
			case 0x4004:
				self.square2.control = data;
			case 0x4005:
				self.square2.sweep = data;
			case 0x4006:
				self.square2.wavelengthLow = data;
			case 0x4007:
				self.square2.lengthCounter = data;
			case 0x4008:
				self.triangle.control = data;
			case 0x4009:
				break;
			case 0x400A:
				self.triangle.wavelengthLow = data;
			case 0x400B:
				self.triangle.lengthCounter = data;
			case 0x400C:
				self.noise.control = data;
			case 0x400D:
				break;
			case 0x400E:
				self.noise.period = data;
			case 0x400F:
				self.noise.lengthCounter = data;
			case 0x4010:
				self.dmcControl = data;
			case 0x4011:
				self.deltaCounterLoad = data;
			case 0x4012:
				self.dmcAddressLoad = data;
			case 0x4013:
				self.dmcLength = data;
			case 0x4014:
				self.transferPPU = data;
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
			// TODO: Handle 4015 read
		} else {
			print("Invalid read at \(address)");
		}
		
		return 0;
	}
}