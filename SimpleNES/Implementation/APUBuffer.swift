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
	private let BUFFERSIZE = 500000;
	// 31250
	private let IDEALCAPACITY = 500000 * 0.7;
	private let CPUFREQENCY = 1789773;
	private let SAMPLERATE = 44100;
	private let SAMPLERATEDIVISOR = 1789773.0 / 44100.0;
	private let ALPHA = 0.000005;
	
	private var buffer: [Int16];
	private var startIndex: Int;
	private var endIndex: Int;
	
	private var rollingSamplesToGet: Double;
	
	private var currentSampleRate: Double;
	
	init() {
		self.buffer = [Int16](count: BUFFERSIZE, repeatedValue: 0);
		
		self.startIndex = 0;
		self.endIndex = Int(IDEALCAPACITY);
		
		self.currentSampleRate = Double(SAMPLERATE);
		
		self.rollingSamplesToGet = SAMPLERATEDIVISOR;
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
		
//		print(availableSampleCount());
		
		if(self.endIndex >= BUFFERSIZE) {
			self.endIndex = 0;
		}
		
		if(self.startIndex == self.endIndex) {
			print("Buffer overflow");
		}
	}
	
	func loadBuffer(audioBuffer: AudioQueueBufferRef) {
		let array = UnsafeMutablePointer<Int16>(audioBuffer.memory.mAudioData);
		
		let size = Int(audioBuffer.memory.mAudioDataBytesCapacity / 8);
		
//		// Give a 20% tolerence for correction
//		let originalTransferSize = Double(size) / 1.5;
//
//		let sampleCount =
		
		
//		print(capacityModifier);
		
//		if(capacityModifier > 1.03) {
//			capacityModifier = 1.03;
//			print("Increasing");
//		} else if(capacityModifier < 0.97) {
//			print("Decreasing");
//			capacityModifier = 0.97;
//		}
		
//		let finalSampleCount = Int(originalTransferSize * capacityModifier);
//		let samplesToGet = Int(SAMPLERATEDIVISOR * capacityModifier);
//		print("Count: \(availableSampleCount()), Start: \(self.startIndex), End: \(self.endIndex)");
		
		var sampleCount = Double(availableSampleCount());
		
		for i in 0 ..< size {
			var capacityModifier = sampleCount / IDEALCAPACITY;
			
			if(capacityModifier > 1.03) {
				capacityModifier = 1.03;
//				print("Increasing");
			} else if(capacityModifier < 0.97) {
//				print("Decreasing");
				capacityModifier = 0.97;
			}
			
			self.rollingSamplesToGet = ALPHA * SAMPLERATEDIVISOR * capacityModifier + (1 - ALPHA) * self.rollingSamplesToGet;
			let samplesToGet = Int(self.rollingSamplesToGet);
			
//			print(samplesToGet);
			
			array[i] = normalizedSample(samplesToGet);
			
			sampleCount -= Double(samplesToGet);
			
			self.startIndex += samplesToGet;
			
			if(self.startIndex + samplesToGet >= BUFFERSIZE) {
				self.startIndex = self.startIndex + samplesToGet - BUFFERSIZE;
			}
			
			if(self.startIndex == self.endIndex) {
				print("Buffer underflow");
			}
		}
		
//		print(availableSampleCount());
		
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