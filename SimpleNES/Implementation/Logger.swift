//
//  Logger.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 3/31/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

class Logger: NSObject {
	
	let path: String;
	var fileHandle: NSFileHandle?;
	
	init(path: String) {
		self.path = path;
		
		NSFileManager.defaultManager().createFileAtPath(self.path, contents: nil, attributes: nil);
		
		self.fileHandle = NSFileHandle(forWritingAtPath: self.path);
		
		if(self.fileHandle == nil) {
			print("ERROR: Unable to open log file");
		}
	}
	
	func log(string: String) {
		self.fileHandle?.seekToEndOfFile();
		self.fileHandle?.writeData(string.dataUsingEncoding(NSUTF8StringEncoding)!);
	}
	
	func hexString<T : UnsignedIntegerType>(value: T) -> String {
		var string = String(value, radix: 16);
		
		if(value < 16) {
			string = "0" + string;
		}
		
		return string;
	}
	
	func logFormattedInstuction(address: UInt16, opcode: UInt8, A: UInt8, X: UInt8, Y: UInt8, P: UInt8, SP: UInt8) {
		log(String(format: "%@  %@A:%@ X:%@ Y:%@ P:%@ SP:%@\n", hexString(address),
			hexString(opcode).stringByPaddingToLength(42, withString: " ", startingAtIndex: 0),
			hexString(A), hexString(X), hexString(Y), hexString(P),
			hexString(SP)).uppercaseString);
	}
	
	func endLogging() {
		self.fileHandle?.closeFile();
	}
}