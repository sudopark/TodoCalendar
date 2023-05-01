//
//  ScheduleEvent.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation

// MARK: - schedule event

public struct ScheduleEvent {
    
    public let uuid: String
    public var name: String
    public var time: EventTime
    
    public var eventTagId: String?
    
    public var repeating: EventRepeating?
    
    public struct RepeatingTimes {
        public let time: EventTime
        public let turn: Int
    }
    public var repeatingTimes: [RepeatingTimes] = []
    
    public init(uuid: String, name: String, time: EventTime) {
        self.uuid = uuid
        self.name = name
        self.time = time
    }
    
    func isClamped(in period: Range<TimeStamp>) -> Bool {
        if let repeating {
            return repeating.isClamped(with: period)
        } else {
            return time.isClamped(with: period)
        }
    }
}


// MARK: - Schedule make params

public struct ScheduleMakeParams {
    
    public var name: String?
    public var time: EventTime?
    public var eventTagId: String?
    public var repeating: EventRepeating?
    public var showTurn: Bool = false
    
    public init() { }
    
    public var isValidForMaking: Bool {
        return self.name?.isEmpty == false
            && self.time != nil
    }
}


public typealias ScheduleEditParams = ScheduleMakeParams
