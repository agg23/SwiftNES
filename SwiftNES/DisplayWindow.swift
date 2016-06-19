//
//  DisplayWindow.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 4/15/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Cocoa

final class DisplayWindow: NSWindow {
	var controllerIO: ControllerIO?;
	
	override func keyDown(_ theEvent: NSEvent) {
		controllerIO?.buttonPressEvent(Int(theEvent.keyCode));
	}
	
	override func keyUp(_ theEvent: NSEvent) {
		controllerIO?.buttonUpEvent(Int(theEvent.keyCode));
	}
}
