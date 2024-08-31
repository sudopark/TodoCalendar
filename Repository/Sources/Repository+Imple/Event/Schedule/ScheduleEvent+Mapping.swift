//
//  ScheduleEvent+Mapping.swift
//  Repository
//
//  Created by sudo.park on 3/31/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain


enum ScheduleEventCodingKeys: String, CodingKey {
    case uuid
    case name
    case eventTagId = "event_tag_id"
    case time = "event_time"
    case repeating
    case notificationOptions = "notification_options"
    case showTurns = "show_turns"
    case excludeTimes = "exclude_repeatings"
}

private typealias Key = ScheduleEventCodingKeys

extension ScheduleMakeParams {
    
    func asJson() -> [String: Any] {
        var sender: [String: Any] = [:]
        sender[Key.name.rawValue] = self.name
        sender[Key.eventTagId.rawValue] = self.eventTagId?.customTagId
        sender[Key.time.rawValue] = self.time.map { EventTimeMapper(time: $0) }
            .map { $0.asJson() }
        sender[Key.repeating.rawValue] = self.repeating.map { EventRepeatingMapper(repeating: $0) }
            .map { $0.asJson() }
        sender[Key.notificationOptions.rawValue] = self.notificationOptions.map { os in
            return os
                .map { EventNotificationTimeOptionMapper(option: $0) }
                .map { try? $0.asJson() }
        }
        sender[Key.showTurns.rawValue] = self.showTurn
        return sender
    }
}


extension SchedulePutParams {
    
    func asJson() -> [String: Any] {
        var sender: [String: Any] = [:]
        sender[Key.name.rawValue] = self.name
        sender[Key.eventTagId.rawValue] = self.eventTagId?.customTagId
        sender[Key.time.rawValue] = self.time.map { EventTimeMapper(time: $0) }
            .map { $0.asJson() }
        sender[Key.repeating.rawValue] = self.repeating.map { EventRepeatingMapper(repeating: $0) }
            .map { $0.asJson() }
        sender[Key.notificationOptions.rawValue] = self.notificationOptions.map { os in
            return os
                .map { EventNotificationTimeOptionMapper(option: $0) }
                .map { try? $0.asJson() }
        }
        sender[Key.showTurns.rawValue] = self.showTurn
        sender[Key.excludeTimes.rawValue] = self.repeatingTimeToExcludes ?? []
        return sender
    }
}


struct ScheduleEventMapper: Decodable {
    
    let event: ScheduleEvent
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        var event = ScheduleEvent(
            uuid: try container.decode(String.self, forKey: .uuid),
            name: try container.decode(String.self, forKey: .name),
            time: try container.decode(EventTimeMapper.self, forKey: .time).time
        )
        event.eventTagId = (try? container.decode(String.self, forKey: .eventTagId))
            .map { .custom($0) }
        event.repeating = try? container.decode(EventRepeatingMapper.self, forKey: .repeating).repeating
        event.notificationOptions = (try? container.decode([EventNotificationTimeOptionMapper].self, forKey: .notificationOptions).map { $0.option }) ?? []
        event.showTurn = (try? container.decode(Bool.self, forKey: .showTurns)) ?? false
        let excludes: [String] = (try? container.decode([String].self, forKey: .excludeTimes)) ?? []
        event.repeatingTimeToExcludes = Set(excludes)
        self.event = event
    }
}


struct ExcludeScheduleEventTimeParams {
    private let newParams: ScheduleMakeParams
    private let excludeTime: EventTime
    
    init(_ newParams: ScheduleMakeParams, _ excludeTime: EventTime) {
        self.newParams = newParams
        self.excludeTime = excludeTime
    }
    
    func asJson() -> [String: Any] {
        return [
            "new": self.newParams.asJson(),
            "exclude_repeatings": excludeTime.customKey
        ]
    }
}

struct ExcludeRepeatingEventResultMapper: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case newSchedule = "new_schedule"
        case updatedOrigin = "updated_origin"
    }
    
    let result: ExcludeRepeatingEventResult
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.result = .init(
            newEvent: try container.decode(ScheduleEventMapper.self, forKey: .newSchedule).event,
            originEvent: try container.decode(ScheduleEventMapper.self, forKey: .updatedOrigin).event
        )
    }
}

struct RemoveSheduleEventResultMapper: Decodable {
    
    init(from decoder: any Decoder) throws {
    }
}
