//
//  ControllerIO.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 4/15/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

class ControllerIO: NSObject {
	var controllerState: Int = -1;
	var strobeHigh: Bool {
		didSet {
			controllerState = -1;
		}
	};
	
	var aPressed: Bool = false;
	var bPressed: Bool = false;
	
	var selectPressed: Bool = false;
	var startPressed: Bool = false;
	
	var upPressed: Bool = false;
	var downPressed: Bool = false;
	var leftPressed: Bool = false;
	var rightPressed: Bool = false;
	
	override init() {
		self.strobeHigh = false;
	}
	
	func buttonState(_ value: Bool) -> UInt8 {
		return value ? 0x41 : 0x40;
	}
	
	func readState() -> UInt8 {
		self.controllerState += 1;
		
		if(self.strobeHigh || self.controllerState == 0) {
			// Return button A
			return buttonState(self.aPressed);
		}
		
		switch self.controllerState {
			case 1:
				// B
				return buttonState(self.bPressed);
			case 2:
				// Select
				return buttonState(self.selectPressed);
			case 3:
				// Start
				return buttonState(self.startPressed);
			case 4:
				// Up
				return buttonState(self.upPressed);
			case 5:
				// Down
				return buttonState(self.downPressed);
			case 6:
				// Left
				return buttonState(self.leftPressed);
			case 7:
				// Right
				return buttonState(self.rightPressed);
			default:
				break;
		}
		
		self.controllerState = 8;
		return 0x41;
	}
}
