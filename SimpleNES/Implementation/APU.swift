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
	
	private var control: UInt8 {
		didSet {
			self.square1Enable = control & 0x1 == 0x1;
			self.square2Enable = control & 0x2 == 0x2;
			self.triangleEnable = control & 0x4 == 0x4;
			self.noiseEnable = control & 0x8 == 0x8;
			self.dmcEnable = control & 0x10 == 0x10;
			
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
			
			if(!self.dmcEnable) {
				self.dmc.sampleLengthRemaining = 0;
			} else if(self.dmc.sampleLengthRemaining == 0) {
				self.dmc.restart();
			}
			
			self.dmc.dmcIRQ = false;
		}
	}
	
	private var square1Enable: Bool;
	private var square2Enable: Bool;
	private var triangleEnable: Bool;
	private var noiseEnable: Bool;
	private var dmcEnable: Bool;
	
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
	private let dmc: DMC;
	
	private var frameIRQ: Bool;
	private var irqDelay: Int;
	
	private var cycle: Int;
	
	private var sampleBuffer: Double;
	private var sampleCount: Double;
	private var outputCycle: Int;
	var sampleRateDivisor: Double;
	private var evenCycle: Bool;
	
	var cpu: CPU? {
		didSet {
			self.dmc.cpu = cpu;
		}
	}
	var buffer: APUBuffer;
	
	init(memory: Memory) {
		self.control = 0;
		self.square1Enable = false;
		self.square2Enable = false;
		self.triangleEnable = false;
		self.noiseEnable = false;
		self.dmcEnable = false;
		
		self.timerControl = 0;
		self.disableIRQ = false;
		self.framerateSwitch = false;
		
		self.square1 = Square();
		self.square2 = Square(isChannel2: true);
		self.triangle = Triangle();
		self.noise = Noise();
		self.dmc = DMC(memory: memory);
		
		self.frameIRQ = false;
		self.irqDelay = -1;
		
		self.cycle = 0;
		
		self.sampleBuffer = 0;
		self.sampleCount = 0;
		self.outputCycle = 0;
		
		self.sampleRateDivisor = 1789773.0 / 44100.0;
		
		self.evenCycle = true;
		
		self.buffer = APUBuffer();
		
		self.buffer.apu = self;
	}
	
	// MARK: - APU Functions
	
	func step() {
		if(self.evenCycle) {
			// Square timers only tick every other cycle
			self.square1.stepTimer();
			self.square2.stepTimer();
			self.noise.stepTimer();
		}
		
		self.triangle.stepTimer();
		self.dmc.stepTimer();
		
		stepFrame();
		
		let oldCycle = self.outputCycle;
		self.outputCycle += 1;
		
		if(Int(Double(oldCycle) / self.sampleRateDivisor) != Int(Double(self.outputCycle) / self.sampleRateDivisor)) {
			self.sampleBuffer += outputValue();
			self.sampleCount += 1;
			
			self.buffer.saveSample(Int16(self.sampleBuffer / self.sampleCount * 32767));
			
			self.sampleBuffer = 0;
			self.sampleCount = 0;
		} else {
			self.sampleBuffer += outputValue();
			self.sampleCount += 1;
		}
		
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
		var noise: Double = 0;
		var dmc: Double = 0;
		
		if(self.square1Enable) {
			square1 = Double(self.square1.output());
		}
		
		if(self.square2Enable) {
			square2 = Double(self.square2.output());
		}
		
		if(self.triangleEnable) {
			triangle = self.triangle.output() / 8227;
		}
		
		if(self.noiseEnable) {
			noise = Double(self.noise.output()) / 12241;
		}
		
		if(self.dmcEnable) {
			dmc = Double(self.dmc.output()) / 22638;
		}
		
		var square_out: Double = 0;
		
		if(square1 + square2 != 0) {
			square_out = 95.88/(8128/(square1 + square2) + 100);
		}
		
		let tnd_out: Double = 159.79/(1/(triangle + noise + dmc) + 100);
		
		return square_out + tnd_out;
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
				self.dmc.control = data;
			case 0x4011:
				self.dmc.directLoad = data;
			case 0x4012:
				self.dmc.address = data;
			case 0x4013:
				self.dmc.sampleLength = data;
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
			temp |= (self.dmc.sampleLengthRemaining == 0 || !self.dmcEnable) ? 0 : 0x10;
			
			temp |= self.frameIRQ ? 0x40 : 0;
			self.frameIRQ = false;
			
			temp |= (!self.dmc.dmcIRQ || !self.dmcEnable) ? 0 : 0x80;
			
			return temp;
		} else {
//			print(String(format: "Invalid read at %x", address));
		}
		
		return 0;
	}
}