//
//  APU.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/6/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class APU {
	// MARK: - APU Registers
	
	private var control: UInt8 {
		didSet {
			square1Enable = control & 0x1 == 0x1
			square2Enable = control & 0x2 == 0x2
			triangleEnable = control & 0x4 == 0x4
			noiseEnable = control & 0x8 == 0x8
			dmcEnable = control & 0x10 == 0x10
			
			if !square1Enable {
				square1.lengthCounterLoad = 0
			}
			
			if !square2Enable {
				square2.lengthCounterLoad = 0
			}
			
			if !triangleEnable {
				triangle.lengthCounterLoad = 0
			}
			
			if !noiseEnable {
				noise.lengthCounterLoad = 0
			}
			
			if !dmcEnable {
				dmc.sampleLengthRemaining = 0
			} else if dmc.sampleLengthRemaining == 0 {
				dmc.restart()
			}
			
			dmc.dmcIRQ = false
		}
	}
	
	private var square1Enable: Bool
	private var square2Enable: Bool
	private var triangleEnable: Bool
	private var noiseEnable: Bool
	private var dmcEnable: Bool
	
	private var timerControl: UInt8 {
		didSet {
			disableIRQ = timerControl & 0x40 == 0x40
			
			if disableIRQ {
				frameIRQ = false
			}
			
			framerateSwitch = timerControl & 0x80 == 0x80
			
			if evenCycle {
				cycle = 0
			} else {
				cycle = -1
			}
		}
	}
	
	private var disableIRQ: Bool
	
	/**
		If true, 5 frames occur in each frame counter cycle, otherwise 4
	*/
	private var framerateSwitch: Bool
	
	// MARK: - APU Variables
	
	private let square1: Square
	private let square2: Square
	private let triangle: Triangle
	private let noise: Noise
	private let dmc: DMC
	
	private var frameIRQ: Bool
	private var irqDelay: Int
	
	private var cycle: Int
	
	private var sampleBuffer: Double
	private var sampleCount: Double
	private var outputCycle: Int
	var sampleRateDivisor: Double
	private var evenCycle: Bool
	
	var cpu: CPU? {
		didSet {
			dmc.cpu = cpu
		}
	}
	var buffer: APUBuffer
	
	init(memory: Memory) {
		control = 0
		square1Enable = false
		square2Enable = false
		triangleEnable = false
		noiseEnable = false
		dmcEnable = false
		
		timerControl = 0
		disableIRQ = true
		framerateSwitch = false
		
		square1 = Square()
		square2 = Square(isChannel2: true)
		triangle = Triangle()
		noise = Noise()
		dmc = DMC(memory: memory)
		
		frameIRQ = false
		irqDelay = -1
		
		cycle = 0
		
		sampleBuffer = 0
		sampleCount = 0
		outputCycle = 0
		
		sampleRateDivisor = 1789773.0 / 44100.0
		
		evenCycle = true
		
		buffer = APUBuffer()
		
		buffer.apu = self
	}
	
	// MARK: - APU Functions
	
	func step() {
		if evenCycle {
			// Square timers only tick every other cycle
			square1.stepTimer()
			square2.stepTimer()
			noise.stepTimer()
		}
		
		triangle.stepTimer()
		dmc.stepTimer()
		
		stepFrame()
		
		let oldCycle = outputCycle
		outputCycle += 1
		
		if Int(Double(oldCycle) / sampleRateDivisor) != Int(Double(outputCycle) / sampleRateDivisor) {
			sampleBuffer += outputValue()
			sampleCount += 1
			
			buffer.saveSample(Int16(sampleBuffer / sampleCount * 32767))
			
			sampleBuffer = 0
			sampleCount = 0
		} else {
			sampleBuffer += outputValue()
			sampleCount += 1
		}
		
		if irqDelay > -1 {
			irqDelay -= 1
			
			if irqDelay == 0 {
				cpu?.queueIRQ()
				irqDelay = -1
			}
		}
		
		evenCycle = !evenCycle
	}
	
	private func stepFrame() {
		if framerateSwitch {
			switch cycle {
				case 1:
					stepSweep()
					stepLength()
					
					stepEnvelope()
				case 7459:
					stepEnvelope()
				case 14915:
					stepSweep()
					stepLength()
					
					stepEnvelope()
				case 22373:
					stepEnvelope()
				// Step 4 (29829) does nothing
				case 37282:
					// 1 less than 1
					cycle = 0
				default:
					break
			}
			
		} else {
			switch cycle {
				case 7459:
					stepEnvelope()
				case 14915:
					stepSweep()
					stepLength()
					
					stepEnvelope()
				case 22373:
					stepEnvelope()
				case 29830:
					setFrameIRQFlag()
				case 29831:
					setFrameIRQFlag()
					stepSweep()
					stepLength()
					
					stepEnvelope()
					
					irqChanged()
				case 29832:
					setFrameIRQFlag()
				case 37288:
					// One less than 7458
					cycle = 7458
				default:
					break
			}
		}
		
		cycle += 1
	}
	
	private func stepEnvelope() {
		// Increment envelope (Square and Noise)
		square1.stepEnvelope()
		square2.stepEnvelope()
		triangle.stepLinear()
		noise.stepEnvelope()
	}
	
	private func stepSweep() {
		// Increment frequency sweep (Square)
		square1.stepSweep()
		square2.stepSweep()
	}
	
	private func stepLength() {
		// Increment length counters (all)
		square1.stepLength()
		square2.stepLength()
		triangle.stepLength()
		noise.stepLength()
	}
	
	private func setFrameIRQFlag() {
		if !disableIRQ {
			frameIRQ = true
		}
	}
	
	private func irqChanged() {
		if !disableIRQ && frameIRQ {
			irqDelay = 2
		}
	}
	
	func outputValue() -> Double {
		var square1: Double = 0
		var square2: Double = 0
		var triangle: Double = 0
		var noise: Double = 0
		var dmc: Double = 0
		
		if square1Enable {
			square1 = Double(self.square1.output())
		}
		
		if square2Enable {
			square2 = Double(self.square2.output())
		}
		
		if triangleEnable {
			triangle = self.triangle.output() / 8227
		}
		
		if noiseEnable {
			noise = Double(self.noise.output()) / 12241
		}
		
		if(self.dmcEnable) {
			dmc = Double(self.dmc.output()) / 22638
		}
		
		var square_out: Double = 0
		
		if(square1 + square2 != 0) {
			square_out = 95.88/(8128/(square1 + square2) + 100)
		}
		
		let tnd_out: Double = 159.79/(1/(triangle + noise + dmc) + 100)
		
		return square_out + tnd_out
	}
	
	// MARK: - APU Register Access
	
	func cpuWrite(_ address: UInt16, data: UInt8) {
		switch(address) {
			case 0x4000:
				square1.control = data
			case 0x4001:
				square1.sweep = data
			case 0x4002:
				square1.wavelengthLow = data
			case 0x4003:
				if square1Enable {
					square1.lengthCounter = data
				}
			case 0x4004:
				square2.control = data
			case 0x4005:
				square2.sweep = data
			case 0x4006:
				square2.wavelengthLow = data
			case 0x4007:
				if square2Enable {
					square2.lengthCounter = data
				}
			case 0x4008:
				triangle.control = data
			case 0x4009:
				break
			case 0x400A:
				triangle.wavelengthLow = data
			case 0x400B:
				if triangleEnable {
					triangle.lengthCounter = data
				}
			case 0x400C:
				noise.control = data
			case 0x400D:
				break
			case 0x400E:
				noise.period = data
			case 0x400F:
				if noiseEnable {
					noise.lengthCounter = data
				}
			case 0x4010:
				dmc.control = data
			case 0x4011:
				dmc.directLoad = data
			case 0x4012:
				dmc.address = data
			case 0x4013:
				dmc.sampleLength = data
 			case 0x4015:
				control = data
			case 0x4017:
				timerControl = data
			default:
				break
		}
	}
	
	func cpuRead(_ address: UInt16) -> UInt8 {
		if address == 0x4015 {
			var temp: UInt8 = (square1.lengthCounterLoad == 0 || !square1Enable) ? 0 : 1
			temp |= (square2.lengthCounterLoad == 0 || !square2Enable) ? 0 : 0x2
			temp |= (triangle.lengthCounterLoad == 0 || !triangleEnable) ? 0 : 0x4
			temp |= (noise.lengthCounterLoad == 0 || !noiseEnable) ? 0 : 0x8
			temp |= (dmc.sampleLengthRemaining == 0 || !dmcEnable) ? 0 : 0x10
			
			temp |= frameIRQ ? 0x40 : 0
			frameIRQ = false
			
			temp |= (!dmc.dmcIRQ || !dmcEnable) ? 0 : 0x80
			
			return temp
		} else {
//			print(String(format: "Invalid read at %x", address))
		}
		
		return 0
	}
}
