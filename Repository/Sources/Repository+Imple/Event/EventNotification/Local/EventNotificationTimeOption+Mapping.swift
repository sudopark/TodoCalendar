//
//  EventNotificationTimeOption+Mapping.swift
//  Repository
//
//  Created by sudo.park on 1/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions

struct EventNotificationTimeOptionMapper: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case typeText = "type_text"
        case beforeSeconds = "before_seconds"
    }
    
    let option: EventNotificationTimeOption
    init(option: EventNotificationTimeOption) {
        self.option = option
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeText = try container.decode(String.self, forKey: .typeText)
        switch typeText {
        case "at_time":
            self = .init(option: .atTime)
            
        case "before":
            let seconds = try container.decode(Double.self, forKey: .beforeSeconds)
            self = .init(option: .before(seconds: seconds))
            
        case "allDay9AM":
            self = .init(option: .allDay9AM)
            
        case "allDay12AM":
            self = .init(option: .allDay12AM)
            
        case "allDay9AMBefore":
            let seconds = try container.decode(Double.self, forKey: .beforeSeconds)
            self = .init(option: .allDay9AMBefore(seconds: seconds))
            
        default:
            throw RuntimeError("invalid value")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.typeText, forKey: .typeText)
        try? container.encode(self.beforeSeconds, forKey: .beforeSeconds)
    }
    
    private var typeText: String {
        switch self.option {
        case .atTime: return "at_time"
        case .before: return "before"
        case .allDay9AM: return "allDay9AM"
        case .allDay12AM: return "allDay12AM"
        case .allDay9AMBefore: return "allDay9AMBefore"
        }
    }
    
    private var beforeSeconds: TimeInterval? {
        switch self.option {
        case .before(let seconds), .allDay9AMBefore(let seconds): return seconds
        default: return nil
        }
    }
}
