//
//  ControllerIO.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 4/15/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation
import Carbon

class ControllerIO: NSObject {
	var controllerState: Int = -1;
	var strobeHigh = false;
	
	var aPressed: Bool = false;
	var bPressed: Bool = false;
	
	var selectPressed: Bool = false;
	var startPressed: Bool = false;
	
	var upPressed: Bool = false;
	var downPressed: Bool = false;
	var leftPressed: Bool = false;
	var rightPressed: Bool = false;
	
	func buttonPressEvent(value: Int) {
		switch(value) {
			case kVK_ANSI_X:
				aPressed = true;
			case kVK_ANSI_Z:
				bPressed = true;
			case kVK_ANSI_A:
				selectPressed = true;
			case kVK_ANSI_S:
				startPressed = true;
			case kVK_UpArrow:
				upPressed = true;
			case kVK_DownArrow:
				downPressed = true;
			case kVK_LeftArrow:
				leftPressed = true;
			case kVK_RightArrow:
				rightPressed = true;
			default:
				break;
		}
	}
	
	func buttonUpEvent(value: Int) {
		switch(value) {
			case kVK_ANSI_X:
				aPressed = false;
			case kVK_ANSI_Z:
				bPressed = false;
			case kVK_ANSI_A:
				selectPressed = false;
			case kVK_ANSI_S:
				startPressed = false;
			case kVK_UpArrow:
				upPressed = false;
			case kVK_DownArrow:
				downPressed = false;
			case kVK_LeftArrow:
				leftPressed = false;
			case kVK_RightArrow:
				rightPressed = false;
			default:
				break;
		}
	}
	
	func buttonState(value: Bool) -> UInt8 {
		return value ? 0x41 : 0x40
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
				print("B \(self.bPressed)");
				return buttonState(self.bPressed);
			case 2:
				// Select
				print("Select \(self.selectPressed)");
				return buttonState(self.selectPressed);
			case 3:
				// Start
				print("Start \(self.startPressed)");
				return buttonState(self.startPressed);
			case 4:
				// Up
				print("Up \(self.upPressed)");
				return buttonState(self.upPressed);
			case 5:
				// Down
				print("Down \(self.downPressed)");
				return buttonState(self.downPressed);
			case 6:
				// Left
				print("Left \(self.leftPressed)");
				return buttonState(self.leftPressed);
			case 7:
				// Right
				print("Right \(self.rightPressed)");
				self.controllerState = -1;
				return buttonState(self.rightPressed);
			default:
				break;
		}
		
		return 0;
	}
}