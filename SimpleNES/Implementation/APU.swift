//
//  APU.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 5/6/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class APU {
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
			
			if(self.disableIRQ) {
				self.frameIRQ = false;
			}
			
			self.framerateSwitch = timerControl & 0x80 == 0x80;
			
			if(self.evenCycle) {
				self.cycle = 0;
			} else {
				self.cycle = -1;
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
	
	private var frameIRQ: Bool;
	private var irqDelay: Int;
	
	private var cycle: Int;
	
	private var sampleCount: Int;
	
	var output: [Int16];
	var outputIndex: Int;
	
	private var evenCycle: Bool;
	
	var cpu: CPU?;
	var buffer: APUBuffer;
	
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
		self.square2 = Square(isChannel2: true);
		self.triangle = Triangle();
		self.noise = Noise();
		
		self.frameIRQ = false;
		self.irqDelay = -1;
		
		self.cycle = 0;
		
		self.sampleCount = 0;
		
		self.output = [Int16](count: 0x2000, repeatedValue: 0);
		self.outputIndex = 0;
		
		self.evenCycle = true;
		
		self.buffer = APUBuffer();
	}
	
	// MARK: - APU Functions
	
	func step() {
		if(self.evenCycle) {
			// Square timers only tick every other cycle
			self.square1.stepTimer();
			self.square2.stepTimer();
		}
		
		self.triangle.stepTimer();
		
		stepFrame();
		
//		let sample1 = Int(Double(self.sampleCount) / (1789773.0 / 44100.0));
//		let sample2 = Int(Double(self.sampleCount + 1) / (1789773.0 / 44100.0));
//		
//		//1789773 / 44100.0
//		if(sample1 != sample2) {
//			self.sampleCount = 0;
//			loadOutput();
//		} else {
//			self.sampleCount += 1;
//		}
		
		self.buffer.saveSample(Int16(outputValue() * 32767));
		
		if(self.irqDelay > -1) {
			self.irqDelay -= 1;
			
			if(self.irqDelay == 0) {
				self.cpu!.queueInterrupt(CPU.Interrupt.IRQ);
				self.irqDelay = -1;
			}
		}
		
		self.evenCycle = !self.evenCycle;
	}
	
	private func stepFrame() {
		if(self.framerateSwitch) {
			switch self.cycle {
				case 1:
					stepSweep();
					stepLength();
					
					stepEnvelope();
				case 7459:
					stepEnvelope();
				case 14915:
					stepSweep();
					stepLength();
					
					stepEnvelope();
				case 22373:
					stepEnvelope();
				// Step 4 (29829) does nothing
				case 37282:
					// 1 less than 1
					self.cycle = 0;
				default:
					break;
			}
			
		} else {
			switch self.cycle {
				case 7459:
					stepEnvelope();
				case 14915:
					stepSweep();
					stepLength();
					
					stepEnvelope();
				case 22373:
					stepEnvelope();
				case 29830:
					setFrameIRQFlag();
				case 29831:
					setFrameIRQFlag();
					stepSweep();
					stepLength();
					
					stepEnvelope();
					
					irqChanged();
				case 29832:
					setFrameIRQFlag();
				case 37288:
					// One less than 7458
					self.cycle = 7458;
				default:
					break;
			}
		}
		
		self.cycle += 1;
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
	
	private func setFrameIRQFlag() {
		if(!self.disableIRQ) {
			self.frameIRQ = true;
		}
	}
	
	private func irqChanged() {
		if(!self.disableIRQ && self.frameIRQ) {
			self.irqDelay = 2;
		}
	}
	
	func outputValue() -> Double {
		var square1: Double = 0;
		var square2: Double = 0;
		var triangle: Double = 0;
		
		if(self.square1Enable) {
			square1 = Double(self.square1.output());
		}
		
		if(self.square2Enable) {
			square2 = Double(self.square2.output());
		}
		
		if(self.triangleEnable) {
			triangle = self.triangle.output() / 8227;
		}
		
		var square_out: Double = 0;
		
		if(square1 + square2 != 0) {
			square_out = 95.88/(8128/(square1 + square2) + 100);
		}
		
		var tnd_out: Double = 0;
		
		if(triangle != 0) {
			tnd_out = 159.79/(1/(triangle + 0 + 0) + 100);
		}
		
		return square_out + tnd_out;
	}
	
//	func loadOutput() {
//		let int_sample = Int16(outputValue() * 32767);
//		
//		self.output[self.outputIndex] = int_sample;
//		
//		self.outputIndex += 1;
//		
//		if(self.outputIndex > 0x2000) {
//			print("wrap");
//			self.outputIndex = 0;
//		}
//	}
	
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
			temp |= self.frameIRQ ? 0x40 : 0;
			self.frameIRQ = false;
			// TODO: Return DMC IRQ status
			
			return temp;
		} else {
//			print(String(format: "Invalid read at %x", address));
		}
		
		return 0;
	}
}