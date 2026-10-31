//
//  EventTimeMapper.swift
//  EventDomain
//
//  Created by sudo.park on 3/10/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions
import RemoteInfraInterface
import EventDomainInterface


public struct EventTimeMapper: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case timeType = "time_type"
        case timestamp
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case secondsFromGmt = "seconds_from_gmt"
    }
    
    public let time: EventTime
    public init(time: EventTime) {
        self.time = time
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type: String = try container.decode(String.self, forKey: .timeType)
        switch type {
        case "at":
            let timeStamp = try container.decode(TimeInterval.self, forKey: .timestamp)
            self.time = .at(timeStamp)
        case "period":
            let start = try container.decode(TimeInterval.self, forKey: .periodStart)
            let end = try container.decode(TimeInterval.self, forKey: .periodEnd)
            self.time = .period(start..<end)
        case "allday":
            let start = try container.decode(TimeInterval.self, forKey: .periodStart)
            let end = try container.decode(TimeInterval.self, forKey: .periodEnd)
            let offset = try container.decode(TimeInterval.self, forKey: .secondsFromGmt)
            self.time = .allDay(start..<end, secondsFromGMT: offset)
            
        default:
            throw RuntimeError("not support event time type: \(type)")
        }
    }
    
    public func asJson() -> [String: Any] {
        switch self.time {
        case .at(let time):
            return [
                "time_type": "at",
                "timestamp": time
            ]
        case .period(let range):
            return [
                "time_type": "period",
                "period_start": range.lowerBound,
                "period_end": range.upperBound
            ]
        case .allDay(let range, let secondsFromGMT):
            return [
                "time_type": "allday",
                "period_start": range.lowerBound,
                "period_end": range.upperBound,
                "seconds_from_gmt": secondsFromGMT
            ]
        }
    }
    
}
