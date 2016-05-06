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
		/*
		Register 4 bits
		*/
		// 3 bits
		var msbWavelength: UInt8;
		// 5 bits
		var lengthCounterLoad: UInt8;
		
		init() {
			self.msbWavelength = 0;
			self.lengthCounterLoad = 0;
		}
		
		func stepLength() {
			
		}
	}
	
	private class Square: APURegister {
		
		/*
			Register 1 bits
		*/
		// 4 bits
		var volume: UInt8;
		var envelopeDisable: Bool;
		var lengthCounterDisable: Bool;
		
		// 2 bits
		var dutyCycleType: UInt8;
		
		/*
			Register 2 bits
		*/
		// 3 bits
		var rightShiftAmount: UInt8;
		var decreaseWavelength: Bool;
		
		// 3 bits
		var sweepUpdateRate: UInt8;
		var sweepEnable: Bool;
		
		/*
			Register 3 bits
		*/
		var lsbWavelength: UInt8;
		
		override init() {
			self.volume = 0;
			self.envelopeDisable = false;
			self.lengthCounterDisable = false;
			self.dutyCycleType = 0;
			
			self.rightShiftAmount = 0;
			self.decreaseWavelength = false;
			self.sweepUpdateRate = 0;
			self.sweepEnable = false;
			
			self.lsbWavelength = 0;
		}
		
		func stepSweep() {
			
		}
		
		func stepEnvelope() {
			
		}
	}
	
	private class Triangle: APURegister {
		
		/*
			Register 1 bits
		*/
		// 7 bits
		var linearCounterLoad: UInt8;
		var lengthCounterClockDisable: Bool;
		
		/*
			Register 3 bits
		*/
		var lsbWavelength: UInt8;
		
		override init() {
			self.linearCounterLoad = 0;
			self.lengthCounterClockDisable = false;
			
			self.lsbWavelength = 0;
		}
		
		func stepLinear() {
			
		}
	}
	
	private class Noise: APURegister {
		
		/*
			Register 1 bits
		*/
		// 4 bits
		var volume: UInt8;
		var envelopeDisable: Bool;
		var lengthCounterDisable: Bool;
		
		// 2 bits
		var dutyCycleType: UInt8;
		
		/*
			Register 3 bits
		*/
		// 4 bits
		var sampleRate: UInt8;
		
		// 3 unused bits
		
		var randomNumberGeneration: Bool;
		
		// 3 unused bits in register 4 (msbWavelength)
		
		override init() {
			self.volume = 0;
			self.envelopeDisable = false;
			self.lengthCounterDisable = false;
			self.dutyCycleType = 0;
			
			self.sampleRate = 0;
			self.randomNumberGeneration = false;
		}
		
		func stepEnvelope() {
			
		}
	}
	
	// MARK: - APU Registers
	
	private var timerControl:UInt8 {
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
}