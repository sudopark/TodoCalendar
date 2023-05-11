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

public struct ScheduleEvent {
    
    public let uuid: String
    public var name: String
    public var time: EventTime
    
    public var eventTagId: String?
    
    public var repeating: EventRepeating?
    public var showTurn: Bool = false
    
    public struct RepeatingTimes {
        public let time: EventTime
        public let turn: Int
        
        var customKey: String {
            switch self.time {
            case .at(let time): return "\(time.utcTimeInterval)"
            case .period(let range):
                return "\(range.lowerBound.utcTimeInterval)..<\(range.upperBound.utcTimeInterval)"
            }
        }
    }
    var nextRepeatingTimes: [RepeatingTimes] = []
    public var repeatingTimes: [RepeatingTimes] {
        return [.init(time: self.time, turn: 1)] + self.nextRepeatingTimes
    }
    public var repeatingTimeToExcludes: Set<String> = []
    
    public init(uuid: String, name: String, time: EventTime) {
        self.uuid = uuid
        self.name = name
        self.time = time
    }
    
    func isOverlap(with period: Range<TimeStamp>) -> Bool {
        if let repeating {
            return repeating.isOverlap(with: period)
        } else {
            return time.isOverlap(with: period)
        }
    }
}


// MARK: - Schedule make params

public struct ScheduleMakeParams {
    
    public var name: String?
    public var time: EventTime?
    public var eventTagId: String?
    public var repeating: EventRepeating?
    public var showTurn: Bool?
    
    public init() { }
    
    public var isValidForMaking: Bool {
        return self.name?.isEmpty == false
            && self.time != nil
    }
}


public struct ScheduleEditParams {
    
    public enum RepeatingUpdateScope: Equatable {
        case all
        case onlyThisTime(EventTime)
    }
    
    public var name: String?
    public var time: EventTime?
    public var eventTagId: String?
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
                || self.eventTagId?.isEmpty == false
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
