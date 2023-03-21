//
//  Times.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


public enum DayOfWeeks {
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
}

public struct FixedDate: Comparable {
    
    private let selectedDate: Date
    private let utcOffset: TimeInterval
    
    public var date: Date {
        let offset = utcOffset * 3600
        return self.selectedDate.addingTimeInterval(offset)
    }
    
    public static func < (lhs: FixedDate, rhs: FixedDate) -> Bool {
        return lhs.date < rhs.date
    }
}
