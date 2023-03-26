//
//  EventRepeating.swift
//  Domain
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation


// MARK: - event repeating

public struct EventRepeating {
    
    public enum RepeatOptions {
        case everyDay
        case everyWeek
        case every2weeks
        case every3weeks
        case every4weeks
        case everyMonth
        case everyYear
        case everyLastDayOfMonth
        case every1stDayOf(DayOfWeeks)
        case every2ndDayOf(DayOfWeeks)
        case every3rdDayOf(DayOfWeeks)
        case every4thDayOf(DayOfWeeks)
    }
    
    public var repeatOption: RepeatOptions
    public var repeatingEndTime: Date?

    public init(repeatingStartTime: Date,
                repeatOption: RepeatOptions) {
        self.repeatOption = repeatOption
    }
}
