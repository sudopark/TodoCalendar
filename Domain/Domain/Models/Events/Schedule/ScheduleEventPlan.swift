//
//  ScheduleEventPlan.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


// MARK: - schedule event repeating

public struct ScheduleEventRepeating {
    
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
    
    public let repeatingStartTime: Date
    public let repeatOption: RepeatOptions
    public var repeatingEndTime: Date?
    
    public let eventTime: ScheduleTime
    
    public init(repeatingStartTime: Date,
                repeatOption: RepeatOptions,
                eventTime: ScheduleTime) {
        self.repeatingStartTime = repeatingStartTime
        self.repeatOption = repeatOption
        self.eventTime = eventTime
    }
}


// MARK: - schedule event plan time

public enum ScheduleEventPlanTime {
    case notRepeating(ScheduleEvent)
    case repeating(ScheduleEventRepeating)
}

public struct ScheduleEventPlan {
    
    public let uuid: String
    public var name: String
    public var tagId: String?
    public var isCountTurn: Bool = false
    
    public var planTime: ScheduleEventPlanTime
    
    public init(uuid: String, name: String, planTime: ScheduleEventPlanTime) {
        self.uuid = uuid
        self.name = name
        self.planTime = planTime
    }
}
