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

enum TodoCodingKeys: String, CodingKey {
    case uuid
    case name
    case createTime = "create_timestamp"
    case eventTagId = "event_tag_id"
    case time = "event_time"
    case repeating
    case notificationOptions = "notification_options"
    case syncTimestamp
    
    // done
    case originEventId = "origin_event_id"
    case doneAt = "done_at"
}

private typealias Key = TodoCodingKeys

extension TodoMakeParams {
    
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
        return sender
    }
}

extension TodoEditParams {
    
    func asJson() -> [String: Any] {
        var sender = [String: Any]()
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

struct TodoEventMapper: Decodable {
    
    let todo: TodoEvent
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TodoCodingKeys.self)
        var todo = TodoEvent(
            uuid: try container.decode(String.self, forKey: .uuid),
            name: try container.decode(String.self, forKey: .name)
        )
        todo.creatTimeStamp = try? container.decode(TimeInterval.self, forKey: .createTime)
        let customEventTagId: String? = try? container.decode(String.self, forKey: .eventTagId)
        todo.eventTagId = customEventTagId.map { .custom($0) }
        todo.time = try? container.decode(EventTimeMapper.self, forKey: .time).time
        todo.repeating = try? container.decode(EventRepeatingMapper.self, forKey: .repeating).repeating
        todo.notificationOptions = (try? container.decode([EventNotificationTimeOptionMapper].self, forKey: .notificationOptions).map { $0.option }) ?? []
        todo.syncTimestamp = try? container.decode(Int.self, forKey: .syncTimestamp)
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
        case syncTimestamp
    }
    
    let result: CompleteTodoResult
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.result = .init(
            doneEvent: try container.decode(DoneTodoEventMapper.self, forKey: .done).event,
            nextRepeatingTodoEvent: try? container.decode(TodoEventMapper.self, forKey: .nextRepeating).todo
        )
        |> \.syncTimestamp .~ (try? container.decode(Int.self, forKey: .syncTimestamp))
    }
}

struct ReplaceRepeatingTodoEventResultMapper: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case newTodo = "new_todo"
        case nextRepeating = "next_repeating"
        case syncTimestamp
    }
    
    let result: ReplaceRepeatingTodoEventResult
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.result = .init(
            newTodoEvent: try container.decode(TodoEventMapper.self, forKey: .newTodo).todo
        )
        |> \.nextRepeatingTodoEvent .~ (try? container.decode(TodoEventMapper.self, forKey: .nextRepeating).todo)
        |> \.syncTimestamp .~ (try? container.decode(Int.self, forKey: .syncTimestamp))
    }
}


struct RemoveTodoResultMapper: Decodable {
    
    let status: String
    var syncTimestamp: Int?
    
    private enum CodingKeys: String, CodingKey {
        case status
        case syncTimestamp
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decode(String.self, forKey: .status)
        self.syncTimestamp = try? container.decode(Int.self, forKey: .syncTimestamp)
    }
}


extension DoneTodoLoadPagingParams {
    
    func asJson() -> [String: Any] {
        var sender: [String: Any] = [:]
        sender["cursor"] = self.cursorAfter
        sender["size"] = self.size
        return sender
    }
}

extension RemoveDoneTodoScope {
    
    func asJson() -> [String: Any] {
        switch self {
        case .all: return [:]
        case .pastThan(let time): return ["past_than": time]
        }
    }
}


// MARK: - toggling

struct RevertToggleTodoDoneParameter {
    let origin: TodoEvent
    let doneTodoId: String?
    
    init(_ origin: TodoEvent, _ doneTodoId: String?) {
        self.origin = origin
        self.doneTodoId = doneTodoId
    }
    
    func asJson() -> [String: Any] {
        var originPayload: [String: Any] = [:]
        originPayload[Key.uuid.rawValue] = self.origin.uuid
        originPayload[Key.name.rawValue] = self.origin.name
        originPayload[Key.createTime.rawValue] = self.origin.creatTimeStamp
        originPayload[Key.eventTagId.rawValue] = self.origin.eventTagId?.customTagId
        originPayload[Key.time.rawValue] = self.origin.time.map { EventTimeMapper(time: $0) }
            .map { $0.asJson() }
        originPayload[Key.repeating.rawValue] = self.origin.repeating.map { EventRepeatingMapper(repeating: $0) }
            .map { $0.asJson() }
        originPayload[Key.notificationOptions.rawValue] = self.origin.notificationOptions
            .map { EventNotificationTimeOptionMapper(option: $0) }
            .map { try? $0.asJson() }
        
        var payload: [String: Any] = [
            "origin": originPayload
        ]
        payload["done_id"] = doneTodoId
        return payload
    }
}


struct RevertToggleTodoDoneResult: Decodable {
    let reverted: TodoEvent
    let deletedDoneTodoId: String?
    
    init(reverted: TodoEvent, deletedDoneTodoId: String?) {
        self.reverted = reverted
        self.deletedDoneTodoId = deletedDoneTodoId
    }
    
    private enum CodingKeys: String, CodingKey {
        case reverted
        case deletedDoneTodoId = "deleted_done_id"
    }
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.reverted = try container.decode(TodoEventMapper.self, forKey: .reverted).todo
        self.deletedDoneTodoId = try? container.decode(String.self, forKey: .deletedDoneTodoId)
    }
}
