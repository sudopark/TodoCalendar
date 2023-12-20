//
//  RuntimeError.swift
//  Extensions
//
//  Created by sudo.park on 2023/03/25.
//

import Foundation


public struct RuntimeError: Error {
    
    public let key: String
    public let message: String
    
    public init(key: String = "default", _ message: String) {
        self.key = key
        self.message = message
    }
}
