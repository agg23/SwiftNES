//
//  APUBuffer.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 5/10/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation
import AudioToolbox

final class APUBuffer {
	var apu: APU?;
	
	private let BUFFERSIZE = 44100;
	// 31250
	private let IDEALCAPACITY = 44100 * 0.2;
	private let CPUFREQENCY = 1789773.0;
	private let SAMPLERATE = 44100.0;
	private let SAMPLERATEDIVISOR = 1789773.0 / 44100.0;
	private let ALPHA = 0.00005;
	private let FILLBUFFERCOUNT = 60;
	
	private var fillBuffer: [Int];
	private var fillBufferIndex: Int;
	private var buffer: [Int16];
	private var startIndex: Int;
	private var endIndex: Int;
	
	private var rollingSamplesToGet: Double;
	
	private var currentSampleRate: Double;
	
	init() {
		self.apu = nil;
		
		self.fillBuffer = [Int](count: FILLBUFFERCOUNT, repeatedValue: Int(IDEALCAPACITY));
		self.fillBufferIndex = 0;
		
		self.buffer = [Int16](count: BUFFERSIZE, repeatedValue: 0);
		
		self.startIndex = 0;
		self.endIndex = Int(IDEALCAPACITY);
		
		self.currentSampleRate = Double(SAMPLERATE);
		
		self.rollingSamplesToGet = SAMPLERATEDIVISOR;
	}
	
	func linearRegression() -> Double {
		var sumX = 0;
		var sumY = 0;
		var sumXY = 0;
		var sumXSquared = 0;
		var sumYSquared = 0;
		
		for i in 0 ..< FILLBUFFERCOUNT {
			let y = self.fillBuffer[i];
			sumX = sumX + i;
			sumY = sumY + y;
			sumXY = sumXY + i * y;
			sumXSquared = sumXSquared + i * i;
			sumYSquared = sumYSquared + y * y;
		}
		
		let slope = Double(FILLBUFFERCOUNT * sumXY - sumX * sumY) / Double(FILLBUFFERCOUNT * sumXSquared - sumX * sumX);
		
		return slope;
	}
	
	func updateRegression() {
		let count = availableSampleCount();
		fillBuffer[self.fillBufferIndex] = count;
		
		self.fillBufferIndex += 1;
		
		if(self.fillBufferIndex >= FILLBUFFERCOUNT) {
			self.fillBufferIndex = 0;
		}
	}
	
	func availableSampleCount() -> Int {
		if(self.endIndex < self.startIndex) {
			return BUFFERSIZE - self.startIndex + self.endIndex;
		}
		
		return self.endIndex - self.startIndex;
	}
	
	func saveSample(sampleData: Int16) {
		self.buffer[self.endIndex] = sampleData;
		
		self.endIndex += 1;
				
		if(self.endIndex >= BUFFERSIZE) {
			self.endIndex = 0;
		}
		
		if(self.startIndex == self.endIndex) {
			print("Buffer overflow");
		}
	}
	
	func loadBuffer(audioBuffer: AudioQueueBufferRef) {
		let array = UnsafeMutablePointer<Int16>(audioBuffer.memory.mAudioData);
		
		let size = Int(audioBuffer.memory.mAudioDataBytesCapacity / 2);
		
		let sampleCount = Double(availableSampleCount());
		
		let capacityModifier = sampleCount / IDEALCAPACITY;
		
		self.rollingSamplesToGet = ALPHA * SAMPLERATEDIVISOR * capacityModifier + (1 - ALPHA) * self.rollingSamplesToGet;
		
		self.apu!.sampleRateDivisor = self.rollingSamplesToGet;
		
		for i in 0 ..< size {
			array[i] = self.buffer[self.startIndex];
			
			self.startIndex += 1;

			if(self.startIndex >= BUFFERSIZE) {
				self.startIndex = 0;
			}

			if(self.startIndex == self.endIndex) {
				print("Buffer underflow");
			}
		}
		
		audioBuffer.memory.mAudioDataByteSize = UInt32(size * 2);
	}
	
	func normalizedSample(sampleCount: Int) -> Int16 {
		var accumulator: Int = 0;
		
		for i in 0 ..< sampleCount {
			let index = (self.startIndex + i) % BUFFERSIZE;
			accumulator += Int(self.buffer[index]);
		}
		
		return Int16(accumulator / sampleCount);
	}
}