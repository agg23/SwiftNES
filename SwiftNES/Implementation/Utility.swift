//
//  Utility.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 9/30/17.
//  Copyright © 2017 Adam Gastineau. All rights reserved.
//

import Foundation

extension Array {
    subscript(i: UInt16) -> Element {
        get {
            return self[Int(i)]
        } set(from) {
            self[Int(i)] = from
        }
    }
}
