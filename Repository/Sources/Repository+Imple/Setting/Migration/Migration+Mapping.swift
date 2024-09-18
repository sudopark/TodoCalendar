//
//  Migration+Mapping.swift
//  Repository
//
//  Created by sudo.park on 4/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain

struct BatchWriteResult: Decodable {

    init(from decoder: any Decoder) throws { }
}

struct BatchEventTagPayload {
    
    private let tags: [EventTag]
    init(tags: [EventTag]) {
        self.tags = tags
    }
    
    func asJson() -> [String: Any] {
        return self.tags.reduce(into: [String: Any]()) { acc, tag in
            let params = EventTagMakeParams(name: tag.name, colorHex: tag.colorHex)
            acc[tag.uuid] = params.asJson()
        }
    }
}

struct BatchTodoEventPayload {
    
    private let todos: [TodoEvent]
    init(todos: [TodoEvent]) {
        self.todos = todos
    }
    
    func asJson() -> [String: Any] {
        return self.todos.reduce(into: [String: Any]()) { acc, todo in
            let params = TodoMakeParams()
                |> \.name .~ todo.name
                |> \.eventTagId .~ todo.eventTagId
                |> \.time .~ todo.time
                |> \.repeating .~ todo.repeating
                |> \.notificationOptions .~ pure(todo.notificationOptions)
            var payload = params.asJson()
            payload[TodoCodingKeys.createTime.rawValue] = todo.creatTimeStamp
            acc[todo.uuid] = payload
        }
    }
}

struct BatchScheduleEventPayload {
    
    private let events: [ScheduleEvent]
    init(events: [ScheduleEvent]) {
        self.events = events
    }
    
    func asJson() -> [String: Any] {
        typealias key = ScheduleEventCodingKeys
        return self.events.reduce(into: [String: Any]()) { acc, event in
            let params = ScheduleMakeParams()
                |> \.name .~ pure(event.name)
                |> \.time .~ pure(event.time)
                |> \.eventTagId .~ event.eventTagId
                |> \.repeating .~ event.repeating
                |> \.showTurn .~ pure(event.showTurn)
                |> \.notificationOptions .~ pure(event.notificationOptions)
            var payload = params.asJson()
            payload[key.excludeTimes.rawValue] = event.repeatingTimeToExcludes.map { $0 }
            acc[event.uuid] = payload
        }
    }
}

struct BatchEventDetailPayload {
    
    private let details: [EventDetailData]
    init(details: [EventDetailData]) {
        self.details = details
    }
    
    func asJson() -> [String: Any] {
        typealias Key = EventDetailDataCodingKeys
        return self.details.reduce(into: [String: Any]()) { acc, data in
            var payload = data.asJson()
            payload[Key.eventId.rawValue] = nil
            acc[data.eventId] = payload
        }
    }
}

struct BatchDoneTodoEventPayload {
    private let dones: [DoneTodoEvent]
    init(dones: [DoneTodoEvent]) {
        self.dones = dones
    }
    func asJson() -> [String: Any] {
        typealias Key = TodoCodingKeys
        func payload(_ done: DoneTodoEvent) -> [String: Any] {
            var sender = [String: Any]()
            sender[Key.name.rawValue] = done.name
            sender[Key.originEventId.rawValue] = done.originEventId
            sender[Key.doneAt.rawValue] = done.doneTime.timeIntervalSince1970
            sender[Key.eventTagId.rawValue] = done.eventTagId?.customTagId
            sender[Key.time.rawValue] = done.eventTime.map {
                EventTimeMapper(time: $0).asJson()
            }
            sender[Key.notificationOptions.rawValue] = done.notificationOptions.compactMap {
                try? EventNotificationTimeOptionMapper(option: $0).asJson()
            }
            return sender
        }
        return self.dones.reduce(into: [String: Any]()) { acc, done in
            acc[done.uuid] = payload(done)
        }
    }
}
