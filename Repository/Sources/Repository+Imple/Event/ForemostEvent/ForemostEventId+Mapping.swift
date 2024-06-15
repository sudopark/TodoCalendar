//
//  ForemostEventId+Mapping.swift
//  Repository
//
//  Created by sudo.park on 6/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain

struct ForemostEventIdMapper: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case isTodo = "is_todo"
    }
    
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
