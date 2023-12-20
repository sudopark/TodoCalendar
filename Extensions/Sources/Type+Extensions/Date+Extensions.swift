//
//  Date+extensions.swift
//  Extensions
//
//  Created by sudo.park on 2023/04/11.
//

import Foundation


extension Date {
    
    public func add(days: Int) -> Date? {
        var addingComponents = DateComponents()
        addingComponents.day = days
        return Calendar(identifier: .gregorian).date(byAdding: addingComponents, to: self)
    }
    
    public func text(_ form: String, timeZone: TimeZone = .current) -> String {
        let format = DateFormatter(); format.timeZone = timeZone
        format.dateFormat = form
        return format.string(from: self)
    }
}
