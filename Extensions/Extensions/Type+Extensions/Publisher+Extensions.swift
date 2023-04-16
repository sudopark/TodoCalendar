//
//  Publisher+extension.swift
//  Extensions
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation
import Combine


extension Publisher where Failure == Never {
    
    public func mapNever() -> Publishers.MapError<Self, Error> {
        return self.mapError { _ -> Error in }
    }
}
