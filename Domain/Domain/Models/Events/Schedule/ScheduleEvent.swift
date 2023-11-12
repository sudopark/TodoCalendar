//
//  ScheduleEvent.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation
import Prelude
import Optics


// MARK: - schedule event

public struct ScheduleEvent: Equatable {
    
    public let uuid: String
    public var name: String
    public var time: EventTime
    
    public var eventTagId: AllEventTagId?
    
    public var repeating: EventRepeating?
    public var showTurn: Bool = false
    
    public struct RepeatingTimes: Equatable {
        public let time: EventTime
        public let turn: Int
        
        public init(time: EventTime, turn: Int) {
            self.time = time
            self.turn = turn
        }
    }
    public var nextRepeatingTimes: [RepeatingTimes] = []
    public var repeatingTimes: [RepeatingTimes] {
        return [.init(time: self.time, turn: 1)] + self.nextRepeatingTimes
    }
    public var repeatingTimeToExcludes: Set<String> = []
    
    public init(uuid: String, name: String, time: EventTime) {
        self.uuid = uuid
        self.name = name
        self.time = time
    }
    
    public init?(_ params: ScheduleMakeParams) {
        guard let name = params.name,
              let time = params.time
        else { return nil }
        self.uuid = UUID().uuidString
        self.name = name
        self.time = time
        self.eventTagId = params.eventTagId
        self.repeating = params.repeating
        self.showTurn = params.showTurn ?? false
    }
    
    func isOverlap(with period: Range<TimeInterval>) -> Bool {
        if let repeating {
            return repeating.isOverlap(with: period, for: self.time)
        } else {
            return time.isOverlap(with: period)
        }
    }
    
    public func apply(_ params: ScheduleEditParams) -> ScheduleEvent {
        return self
            |> \.name .~ (params.name ?? self.name)
            |> \.time .~ (params.time ?? self.time)
            |> \.eventTagId .~ params.eventTagId
            |> \.repeating .~ params.repeating
            |> \.showTurn .~ (params.showTurn ?? false)
    }
}


// MARK: - Schedule make params

public struct ScheduleMakeParams {
    
    public var name: String?
    public var time: EventTime?
    public var eventTagId: AllEventTagId?
    public var repeating: EventRepeating?
    public var showTurn: Bool?
    
    public init() { }
    
    public var isValidForMaking: Bool {
        return self.name?.isEmpty == false
            && self.time != nil
    }
}


public struct ScheduleEditParams: Equatable {
    
    public enum RepeatingUpdateScope: Equatable {
        case all
        case onlyThisTime(EventTime)
    }
    
    public var name: String?
    public var time: EventTime?
    public var eventTagId: AllEventTagId?
    public var repeating: EventRepeating?
    public var repeatingUpdateScope: RepeatingUpdateScope?
    public var showTurn: Bool?
    
    public init() { }
    
    public var isValidForUpdate: Bool {
        switch self.repeatingUpdateScope {
        case .onlyThisTime:
            return self.asMakeParams().isValidForMaking
            
        default:
            return self.name?.isEmpty == false
                || self.eventTagId != nil
                || self.time != nil
                || self.repeating != nil
                || self.showTurn != nil
        }
    }
    
    public func asMakeParams() -> ScheduleMakeParams {
        return ScheduleMakeParams()
            |> \.name .~ self.name
            |> \.eventTagId .~ self.eventTagId
            |> \.time .~ self.time
            |> \.repeating .~ self.repeating
            |> \.showTurn .~ self.showTurn
    }
}

public struct ExcludeRepeatingEventResult {
    
    public let newEvent: ScheduleEvent
    public let originEvent: ScheduleEvent
    
    public init(
        newEvent: ScheduleEvent,
        originEvent: ScheduleEvent
    ) {
        self.newEvent = newEvent
        self.originEvent = originEvent
    }
}


public struct RemoveSheduleEventResult {
    public var nextRepeatingEvnet: ScheduleEvent?
    public init() { }
}
