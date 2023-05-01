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
    
    public var repeatingOption: EventRepeating?
    
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
}


// MARK: - Schedule make params

public struct ScheduleMakeParams {
    
    public var name: String?
    public var time: EventTime?
    public var eventTagId: String?
    public var repeatingOption: EventRepeating?
    public var showTurn: Bool = false
    
    public init() { }
}


public typealias ScheduleEditParams = ScheduleMakeParams
