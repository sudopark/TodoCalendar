//
//  EventTag+Mapping.swift
//  Repository
//
//  Created by sudo.park on 4/6/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain

private enum CodingKeys: String, CodingKey {
    case uuid
    case name
    case colorHex = "color_hex"
    case syncTimestamp
}

struct CustomEventTagMapper: Decodable {
    
    var tag: CustomEventTag
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tag = .init(
            uuid: try container.decode(String.self, forKey: .uuid),
            name: try container.decode(String.self, forKey: .name),
            colorHex: try container.decode(String.self, forKey: .colorHex)
        )
        self.tag.syncTimestamp = try? container.decode(Int.self, forKey: .syncTimestamp)
    }
}

extension CustomEventTagMakeParams {
    
    func asJson() -> [String: Any] {
        return [
            CodingKeys.name.rawValue: self.name,
            CodingKeys.colorHex.rawValue: self.colorHex
        ]
    }
}

struct RemoveEventTagResultMapper: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case syncTimestamp
    }
    
    let result: RemoveCustomEventTagResult
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.result = .init(
            syncTimestamp: try? container.decode(Int.self, forKey: .syncTimestamp)
        )
    }
}


struct RemoveEventTagAndResultMapper: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case todos
        case schedules
        case syncTimestamp
    }
    var result: RemoveCustomEventTagWithEventsResult
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.result = .init(
            todoIds: try container.decode([String].self, forKey: .todos),
            scheduleIds: try container.decode([String].self, forKey: .schedules)
        )
        self.result.syncTimestamp = try? container.decode(Int.self, forKey: .syncTimestamp)
    }
}
