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

struct TodoEventMapper: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case eventTagId = "event_tag_id"
        case time = "event_time"
        case repeating
        case notificationOptions = "notification_options"
    }
    
    let todo: TodoEvent
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
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
