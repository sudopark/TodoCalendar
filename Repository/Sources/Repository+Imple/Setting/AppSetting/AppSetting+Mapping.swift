//
//  AppSetting+Mapping.swift
//  Repository
//
//  Created by sudo.park on 4/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain

private enum TagColorCodingKeys: String, CodingKey {
    case holiday
    case `default`
}

struct EventTagColorSettingMapper: Decodable {
    
    private typealias Keys = TagColorCodingKeys
    
    let setting: DefaultEventTagColorSetting
    
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        self.setting = .init(
            holiday: try container.decode(String.self, forKey: .holiday),
            default: try container.decode(String.self, forKey: .default)
        )
    }
}

extension EditDefaultEventTagColorParams {
    
    func asJson() -> [String: Any] {
        typealias Keys = TagColorCodingKeys
        var sender: [String: Any] = [:]
        sender[Keys.holiday.rawValue] = self.newHolidayTagColor
        sender[Keys.default.rawValue] = self.newDefaultTagColor
        return sender
    }
}
