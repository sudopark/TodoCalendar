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
    public var turn: Int?
    
    public var eventTagId: String?
    
    public var repeating: EventRepeating?
    // 해당 아이디가 존재하면 시작날짜와 같은 날에 있는 반복일정은 예외
    public var exceptFromRepeatedEventId: String?
    
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
    public var repeating: EventRepeating?
    public var exceptFromRepeatedScheduleId: String?
    
    public init() { }
}


public typealias ScheduleEditParams = ScheduleMakeParams
