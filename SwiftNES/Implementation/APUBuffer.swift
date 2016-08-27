//
//  APUBuffer.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 5/10/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation
import AudioToolbox

final class APUBuffer {
	var apu: APU?;
	
	private let BUFFERSIZE = 44100;
	// 8820
	private let IDEALCAPACITY = 44100 * 0.2;
	private let CPUFREQENCY = 1789773.0;
	private let SAMPLERATE = 44100.0;
	private let SAMPLERATEDIVISOR = 1789773.0 / 44100.0;
	private let ALPHA = 0.00005;
	
	private var buffer: [Int16];
	private var startIndex: Int;
	private var endIndex: Int;
	
	private var rollingSamplesToGet: Double;
	
	init() {
		self.apu = nil;
		
		self.buffer = [Int16](repeating: 0, count: BUFFERSIZE);
		
		self.startIndex = 0;
		self.endIndex = Int(IDEALCAPACITY);
		
		self.rollingSamplesToGet = SAMPLERATEDIVISOR;
	}
	
	func availableSampleCount() -> Int {
		if(self.endIndex < self.startIndex) {
			return BUFFERSIZE - self.startIndex + self.endIndex;
		}
		
		return self.endIndex - self.startIndex;
	}
	
	func saveSample(_ sampleData: Int16) {
		self.buffer[self.endIndex] = sampleData;
		
		self.endIndex += 1;
		
		if(self.endIndex >= BUFFERSIZE) {
			self.endIndex = 0;
		}
		
		if(self.startIndex == self.endIndex) {
			print("Buffer overflow");
		}
	}
	
	func loadBuffer(_ audioBuffer: AudioQueueBufferRef) {
//		let array = UnsafeMutablePointer<Int16>(audioBuffer.pointee.mAudioData);
		
		let size = Int(audioBuffer.pointee.mAudioDataBytesCapacity / 2);
		
		let array = UnsafeMutableBufferPointer.init(start: audioBuffer.pointee.mAudioData.assumingMemoryBound(to: Int16.self), count: size);
		
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
		
		audioBuffer.pointee.mAudioDataByteSize = UInt32(size * 2);
	}
}
