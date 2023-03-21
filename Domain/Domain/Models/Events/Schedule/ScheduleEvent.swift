//
//  ScheduleEvent.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


// MARK: - Schedule time

public enum ScheduleTime {
    case at(Date)
    case period(ClosedRange<Date>)
    case allDays(Range<FixedDate>)
}


// MARK: - schedule event

public struct ScheduleEvent {
    
    public var name: String
    public var time: ScheduleTime
    public var turn: Int?
    
    public var eventTagId: String?
    
    public init(name: String, time: ScheduleTime) {
        self.name = name
        self.time = time
    }
}
