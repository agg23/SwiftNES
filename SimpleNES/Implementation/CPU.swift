//
//  CPU.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

class CPU: NSObject {
    
    // MARK: Registers
    
    /**
     Lower Half of PC
    */
    var PCL: UInt8;
    
    /**
     Upper Half of PC
    */
    var PCH: UInt8;
    
    /**
     Stack Pointer
    */
    var SP: UInt8;
    
    /**
     Processor Status
    */
    var P: UInt8;
    
    /**
     Accumulator
    */
    var A: UInt8;
    
    /**
     Index Register X
    */
    var X: UInt8;
    
    /**
     Index Register Y
    */
    var Y: UInt8;
    
    /**
     Initializes the CPU
    */
    override init() {
        
    }
    
    /**
     Executes one CPU cycle
    */
    func step() {
        
    }
}