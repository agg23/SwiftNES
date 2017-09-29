//
//  Logger.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 3/31/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class Logger: NSObject {
	
	let path: String
	var fileHandle: FileHandle?
	
	init(path: String) {
		self.path = path
		
		FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
		
		fileHandle = FileHandle(forWritingAtPath: path)
		
		if fileHandle == nil {
			print("ERROR: Unable to open log file")
		}
	}
	
	func log(_ string: String) {
		fileHandle?.write((string + "\n").data(using: String.Encoding.utf8)!)
	}
	
	func hexString<T : UnsignedInteger>(_ value: T, padding: Int) -> String {
		var string = String(value, radix: 16)
		
		for _ in string.characters.count..<padding {
			string = "0" + string
		}
		
		return string
	}
	
	func logFormattedInstuction(_ address: UInt16, opcode: UInt8, A: UInt8, X: UInt8, Y: UInt8, P: UInt8, SP: UInt8, CYC: Int, SL: Int) {
		log(String(format: "%@  %@A:%@ X:%@ Y:%@ P:%@ SP:%@ CYC:%@ SL:%@", hexString(address, padding: 4),
			hexString(opcode, padding: 2).padding(toLength: 42, withPad: " ", startingAt: 0),
			hexString(A, padding: 2), hexString(X, padding: 2), hexString(Y, padding: 2), hexString(P, padding: 2),
			hexString(SP, padding: 2), String(CYC).padding(toLength: 3, withPad: " ", startingAt: 0), String(SL)).uppercased())
	}
	
	func endLogging() {
		fileHandle?.closeFile()
	}
	
	func dumpMemory(_ memory: [UInt8]) {
		for i in 0 ..< memory.count {
			var string = ""
			
			if i % 8 == 0 {
				string += hexString(UInt16(i), padding: 4) + ": "
			}
			
			string += hexString(memory[i], padding: 2) + " "
			
			if i % 8 == 7 {
				string += "\n"
			} else if i % 2 == 1 {
				string += " "
			}
			
			fileHandle?.write(string.uppercased().data(using: String.Encoding.utf8)!)
		}
	}
}
