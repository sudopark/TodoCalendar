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
}

struct EventTagMapper: Decodable {
    
    let tag: EventTag
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tag = .init(
            uuid: try container.decode(String.self, forKey: .uuid),
            name: try container.decode(String.self, forKey: .name),
            colorHex: try container.decode(String.self, forKey: .colorHex)
        )
    }
}

extension EventTagMakeParams {
    
    func asJson() -> [String: Any] {
        return [
            CodingKeys.name.rawValue: self.name,
            CodingKeys.colorHex.rawValue: self.colorHex
        ]
    }
}

struct RemoveEventTagResult: Decodable {
    init(from decoder: any Decoder) throws { }
}
