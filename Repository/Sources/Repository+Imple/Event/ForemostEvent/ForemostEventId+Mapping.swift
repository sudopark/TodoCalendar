//
//  ForemostEventId+Mapping.swift
//  Repository
//
//  Created by sudo.park on 6/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain

private enum CodingKeys: String, CodingKey {
    case eventId = "event_id"
    case isTodo = "is_todo"
    case event
}

struct ForemostEventIdMapper: Codable {
    
    let id: ForemostEventId
    init(id: ForemostEventId) {
        self.id = id
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id:
                .init(
                    try container.decode(String.self, forKey: .eventId),
                    try container.decode(Bool.self, forKey: .isTodo)
                )
        )
    }
   
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id.eventId, forKey: .eventId)
        try container.encode(self.id.isTodo, forKey: .isTodo)
    }
}

extension ForemostEventId {
    
    func asJson() -> [String: Any] {
        typealias Keys = CodingKeys
        return [
            Keys.eventId.rawValue: self.eventId,
            Keys.isTodo.rawValue: self.isTodo
        ]
    }
}

struct ForemostEventIdRemoveResponseMapper: Decodable {
    let status: String
    
    private enum CodingKeys: String, CodingKey {
        case status
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decode(String.self, forKey: .status)
    }
}


struct ForemostMarkableEventResponseMapper: Decodable {
    
    let event: (any ForemostMarkableEvent)?
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let isTodo = try? container.decode(Bool.self, forKey: .isTodo)
        else {
            self.event = nil
            return
        }
        if isTodo {
            let todo = try container.decodeIfPresent(TodoEventMapper.self, forKey: .event)
            self.event = todo?.todo
        } else {
            let schedule = try container.decodeIfPresent(ScheduleEventMapper.self, forKey: .event)
            self.event = schedule?.event
        }
    }
}
