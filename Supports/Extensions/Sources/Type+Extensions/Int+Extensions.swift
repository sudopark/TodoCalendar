//
//  Int+Extensions.swift
//  Extensions
//
//  Created by sudo.park on 2023/06/27.
//

import Foundation


extension Int {
    
    public func withLeadingZero() -> String {
        return String(format: "%02d", self)
    }
    
    public var ordinal: String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: self))
    }
}
