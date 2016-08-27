//
//  MacControllerIO.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 8/27/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation
import Carbon

final class MacControllerIO: ControllerIO {
	func buttonPressEvent(_ value: Int) {
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
	
	func buttonUpEvent(_ value: Int) {
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
}
