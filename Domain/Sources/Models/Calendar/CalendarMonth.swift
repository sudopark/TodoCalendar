//
//  CalendarMonth.swift
//  Domain
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation


public struct CalendarMonth: Hashable, Comparable, Sendable {
    
    public let year: Int
    public let month: Int
    
    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }
    
    public static func < (lhs: CalendarMonth, rhs: CalendarMonth) -> Bool {
        return lhs.year * 100 + lhs.month < rhs.year * 100 + rhs.month
    }
    
    public func nextMonth() -> CalendarMonth {
        return self.month == 12
        ? .init(year: self.year + 1, month: 1)
        : .init(year: self.year, month: self.month + 1)
    }
    
    public func previousMonth() -> CalendarMonth {
        return self.month == 1
        ? .init(year: self.year - 1, month: 12)
        : .init(year: self.year, month: self.month - 1)
    }
}


public struct CalendarDay: Hashable, Sendable {
    
    public let year: Int
    public let month: Int
    public let day: Int
    public init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}
