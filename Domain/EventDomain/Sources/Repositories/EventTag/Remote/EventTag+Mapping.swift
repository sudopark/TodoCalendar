//
//  EventTag+Mapping.swift
//  EventDomain
//
//  Created by sudo.park on 4/6/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface
import EventDomainInterface

private enum CodingKeys: String, CodingKey {
    case uuid
    case name
    case colorHex = "color_hex"
    case skipCheckDuplicationName
}

struct CustomEventTagMapper: Decodable {
    
    let tag: CustomEventTag
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tag = .init(
            uuid: try container.decode(String.self, forKey: .uuid),
            name: try container.decode(String.self, forKey: .name),
            colorHex: try container.decode(String.self, forKey: .colorHex)
        )
    }
}

extension CustomEventTagMakeParams {
    
    public func asJson() -> [String: Any] {
        return [
            CodingKeys.name.rawValue: self.name,
            CodingKeys.colorHex.rawValue: self.colorHex,
            CodingKeys.skipCheckDuplicationName.rawValue: self.skipCheckDuplicationName
        ]
    }
}

struct RemoveEventTagResult: Decodable {
    init(from decoder: any Decoder) throws { }
}


struct RemoveEventTagAndResultMapper: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case todos
        case schedules
    }
    let result: RemoveCustomEventTagWithEventsResult
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.result = .init(
            todoIds: try container.decode([String].self, forKey: .todos),
            scheduleIds: try container.decode([String].self, forKey: .schedules)
        )
    }
}
