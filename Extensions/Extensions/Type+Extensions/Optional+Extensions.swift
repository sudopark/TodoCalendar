//
//  Optional+Extensions.swift
//  Extensions
//
//  Created by sudo.park on 2023/06/25.
//

import Foundation


extension Optional {
    
    public func unwrap(_ customError: (() -> Error)? = nil) throws -> Wrapped {
        switch self {
        case .none: throw customError?() ?? RuntimeError("unwrap optional value error: \(String(describing: self))")
        case .some(let value): return value
        }
    }
}
