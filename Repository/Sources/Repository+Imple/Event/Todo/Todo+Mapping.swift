//
//  Todo+Mapping.swift
//  Repository
//
//  Created by sudo.park on 3/10/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain

extension TodoMakeParams {
    
    func asJson() -> [String: Any] {
        var sender: [String: Any] = [:]
        sender["name"] = self.name
        sender["event_tag_id"] = self.eventTagId?.customTagId
        sender["event_time"] = self.time.map { EventTimeMapper(time: $0) }
            .map { $0.asJson() }
        sender["repeating"] = self.repeating.map { EventRepeatingMapper(repeating: $0) }
            .map { $0.asJson() }
        sender["notification_options"] = self.notificationOptions.map { os in
            return os
                .map { EventNotificationTimeOptionMapper(option: $0) }
                .map { try? $0.asJson() }
        }
        return sender
    }
}

extension TodoEditParams {
    
    func asJson() -> [String: Any] {
        var sender = [String: Any]()
        sender["name"] = self.name
        sender["event_tag_id"] = self.eventTagId?.customTagId
        sender["event_time"] = self.time.map { EventTimeMapper(time: $0) }
            .map { $0.asJson() }
        sender["repeating"] = self.repeating.map { EventRepeatingMapper(repeating: $0) }
            .map { $0.asJson() }
        sender["notification_options"] = self.notificationOptions.map { os in
            return os
                .map { EventNotificationTimeOptionMapper(option: $0) }
                .map { try? $0.asJson() }
        }
        return sender
    }
}

struct DoneTodoEventParams {
    private let origin: TodoEvent
    private let nextTime: EventTime?
    
    init(_ origin: TodoEvent, _ nextTime: EventTime?) {
        self.origin = origin
        self.nextTime = nextTime
    }
    
    func asJson() -> [String: Any] {
        let params = TodoMakeParams()
            |> \.name .~ self.origin.name
            |> \.eventTagId .~ self.origin.eventTagId
            |> \.time .~ self.origin.time
            |> \.notificationOptions .~ pure(self.origin.notificationOptions)
        
        return ["origin": params.asJson() ]
            |> key("next_event_time") .~ self.nextTime.map { EventTimeMapper(time: $0).asJson() }
    }
}

struct ReplaceRepeatingTodoEventParams {
    private let newParams: TodoMakeParams
    private let nextTime: EventTime?
    
    init(_ newParams: TodoMakeParams, _ nextTime: EventTime?) {
        self.newParams = newParams
        self.nextTime = nextTime
    }
    
    func asJson() -> [String: Any] {
        let payload: [String: Any] = ["new": self.newParams.asJson()]
        return payload
        |> key("origin_next_event_time") .~ self.nextTime.map { EventTimeMapper(time: $0).asJson() }
    }
}

private enum TodoCodingKeys: String, CodingKey {
    case uuid
    case name
    case eventTagId = "event_tag_id"
    case time = "event_time"
    case repeating
    case notificationOptions = "notification_options"
    
    // done
    case originEventId = "origin_event_id"
    case doneAt = "done_at"
}

struct TodoEventMapper: Decodable {
    
    let todo: TodoEvent
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TodoCodingKeys.self)
        var todo = TodoEvent(
            uuid: try container.decode(String.self, forKey: .uuid),
            name: try container.decode(String.self, forKey: .name)
        )
        let customEventTagId: String? = try? container.decode(String.self, forKey: .eventTagId)
        todo.eventTagId = customEventTagId.map { .custom($0) }
        todo.time = try? container.decode(EventTimeMapper.self, forKey: .time).time
        todo.repeating = try? container.decode(EventRepeatingMapper.self, forKey: .repeating).repeating
        todo.notificationOptions = (try? container.decode([EventNotificationTimeOptionMapper].self, forKey: .notificationOptions).map { $0.option }) ?? []
        self.todo = todo
    }
}

struct DoneTodoEventMapper: Decodable {
    
    let event: DoneTodoEvent
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: TodoCodingKeys.self)
        var done = DoneTodoEvent(
            uuid: try container.decode(String.self, forKey: .uuid),
            name: try container.decode(String.self, forKey: .name),
            originEventId: try container.decode(String.self, forKey: .originEventId),
            doneTime: try container.decodeTimeStampBaseDate(.doneAt)
        )
        let customEventTagId: String? = try? container.decode(String.self, forKey: .eventTagId)
        done.eventTagId = customEventTagId.map { .custom($0) }
        done.eventTime = try? container.decode(EventTimeMapper.self, forKey: .time).time
        done.notificationOptions = (try? container.decode([EventNotificationTimeOptionMapper].self, forKey: .notificationOptions)
                .map { $0.option }) ?? []
        self.event = done
    }
}

struct CompleteTodoResultMapper: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case done
        case nextRepeating = "next_repeating"
    }
    
    let result: CompleteTodoResult
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.result = .init(
            doneEvent: try container.decode(DoneTodoEventMapper.self, forKey: .done).event,
            nextRepeatingTodoEvent: try? container.decode(TodoEventMapper.self, forKey: .nextRepeating).todo
        )
    }
}

struct ReplaceRepeatingTodoEventResultMapper: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case newTodo = "new_todo"
        case nextRepeating = "next_repeating"
    }
    
    let result: ReplaceRepeatingTodoEventResult
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.result = .init(
            newTodoEvent: try container.decode(TodoEventMapper.self, forKey: .newTodo).todo
        )
        |> \.nextRepeatingTodoEvent .~ (try? container.decode(TodoEventMapper.self, forKey: .nextRepeating).todo)
    }
}
