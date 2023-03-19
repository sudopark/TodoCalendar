//
//  EventPlanTime.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation

public struct EventRepeating {
    
    public enum EventRepeatOptions {
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
    
    public let repeatStartTime: Date
    public let repeatOption: EventRepeatOptions
    public var repeatEndTime: Date?
    
    public let relatedStartInterval: TimeInterval
    public var relatedEndInterval: TimeInterval?
    
    public init(repeatStartTime: Date, repeatOption: EventRepeatOptions,
                relatedStartInterval: TimeInterval) {
        self.repeatStartTime = repeatStartTime
        self.repeatOption = repeatOption
        self.relatedStartInterval = relatedStartInterval
    }
}

public enum EventPlanTime {
    case onece(at: Date)
    case repeating(EventRepeating)
}
