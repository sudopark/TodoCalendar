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
    
    public func day(for timeZone: String) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(abbreviation: timeZone)!
        return calendar.dateComponents([.day], from: self).day!
    }
    
    public func string(for timeZone: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(abbreviation: timeZone)
        return formatter.string(from: self)
    }
}
