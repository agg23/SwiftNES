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
	var apu: APU?
	
	private let BUFFERSIZE = 44100
	// 8820
	private let IDEALCAPACITY = 44100 * 0.2
	private let CPUFREQENCY = 1789773.0
	private let SAMPLERATE = 44100.0
	private let SAMPLERATEDIVISOR = 1789773.0 / 44100.0
	private let ALPHA = 0.00005
	
	private var buffer: [Int16]
	private var startIndex: Int
	private var endIndex: Int
	
	private var rollingSamplesToGet: Double
	
	init() {
		apu = nil
		
		buffer = [Int16](repeating: 0, count: BUFFERSIZE)
		
		startIndex = 0
		endIndex = Int(IDEALCAPACITY)
		
		rollingSamplesToGet = SAMPLERATEDIVISOR
	}
	
	func availableSampleCount() -> Int {
		if endIndex < startIndex {
			return BUFFERSIZE - startIndex + endIndex
		}
		
		return endIndex - startIndex
	}
	
	func saveSample(_ sampleData: Int16) {
		buffer[endIndex] = sampleData
		
		endIndex += 1
		
		if endIndex >= BUFFERSIZE {
			endIndex = 0
		}
		
		if startIndex == endIndex {
			print("Buffer overflow")
		}
	}
	
	func loadBuffer(_ audioBuffer: AudioQueueBufferRef) {
//		let array = UnsafeMutablePointer<Int16>(audioBuffer.pointee.mAudioData)
		
		let size = Int(audioBuffer.pointee.mAudioDataBytesCapacity / 2)
		
		let array = UnsafeMutableBufferPointer(start: audioBuffer.pointee.mAudioData.assumingMemoryBound(to: Int16.self), count: size)
		
		let sampleCount = Double(availableSampleCount())
		
		let capacityModifier = sampleCount / IDEALCAPACITY
		
		rollingSamplesToGet = ALPHA * SAMPLERATEDIVISOR * capacityModifier + (1 - ALPHA) * rollingSamplesToGet
		
		apu?.sampleRateDivisor = rollingSamplesToGet
		
		for i in 0 ..< size {
			array[i] = buffer[startIndex]
			
			startIndex += 1

			if startIndex >= BUFFERSIZE {
				startIndex = 0
			}

			if startIndex == endIndex {
				print("Buffer underflow")
			}
		}
		
		audioBuffer.pointee.mAudioDataByteSize = UInt32(size * 2)
	}
}
