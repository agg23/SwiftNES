//
//  iOSControllerIO.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 8/28/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

final class iOSControllerIO: ControllerIO {
	func buttonPressEvent(_ value: Int) {
		switch(value) {
		case 0:
			upPressed = true
		case 1:
			leftPressed = true
		case 2:
			rightPressed = true
		case 3:
			downPressed = true
		case 4:
			selectPressed = true
		case 5:
			startPressed = true
		case 6:
			bPressed = true
		case 7:
			aPressed = true
		default:
			break
		}
	}
	
	func buttonUpEvent(_ value: Int) {
		switch(value) {
		case 0:
			upPressed = false
		case 1:
			leftPressed = false
		case 2:
			rightPressed = false
		case 3:
			downPressed = false
		case 4:
			selectPressed = false
		case 5:
			startPressed = false
		case 6:
			bPressed = false
		case 7:
			aPressed = false
		default:
			break
		}
	}
}
