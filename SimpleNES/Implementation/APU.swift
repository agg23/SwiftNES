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
	
	final class Square {
		
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
		
		/*
			Register 4 bits
		*/
		// 3 bits
		var msbWavelength: UInt8;
		// 5 bits
		var lengthCounterLoad: UInt8;
		
		init() {
			self.volume = 0;
			self.envelopeDisable = false;
			self.lengthCounterDisable = false;
			self.dutyCycleType = 0;
			
			self.rightShiftAmount = 0;
			self.decreaseWavelength = false;
			self.sweepUpdateRate = 0;
			self.sweepEnable = false;
			
			self.lsbWavelength = 0;
			
			self.msbWavelength = 0;
			self.lengthCounterLoad = 0;
		}
	}
	
	final class Triangle {
		
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
		
		/*
			Register 4 bits
		*/
		// 3 bits
		var msbWavelength: UInt8;
		// 5 bits
		var lengthCounterLoad: UInt8;
		
		init() {
			self.linearCounterLoad = 0;
			self.lengthCounterClockDisable = false;
			
			self.lsbWavelength = 0;
			
			self.msbWavelength = 0;
			self.lengthCounterLoad = 0;
		}
	}
	
	final class Noise {
		
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
		
		/*
			Register 4 bits
		*/
		// 3 unused bits
		// 5 bits
		var lengthCounterLoad: UInt8;
		
		init() {
			self.volume = 0;
			self.envelopeDisable = false;
			self.lengthCounterDisable = false;
			self.dutyCycleType = 0;
			
			self.sampleRate = 0;
			self.randomNumberGeneration = false;
			
			self.lengthCounterLoad = 0;
		}
	}
	
	// MARK: - APU Functions
	
	func step() {
		
	}
}