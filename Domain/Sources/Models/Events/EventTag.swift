//
//  EventTag.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


public enum AllEventTagId: Sendable, Hashable {
    case holiday
    case `default`
    case custom(String)
    
    public var customTagId: String? {
        guard case let .custom(id) = self else { return nil }
        return id
    }
}

public struct EventTag: Sendable, Equatable {
    
    public let uuid: String
    public var name: String
    public var colorHex: String
    
    public init(uuid: String, name: String, colorHex: String) {
        self.uuid = uuid
        self.name = name
        self.colorHex = colorHex
    }
    
    public init(name: String, colorHex: String) {
        self.uuid = UUID().uuidString
        self.name = name
        self.colorHex = colorHex
    }
}


public struct EventTagMakeParams {
    public var name: String
    public var colorHex: String
    
    public init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
    }
}

public typealias EventTagEditParams = EventTagMakeParams



public struct RemoveEventTagWithEventsResult: Sendable {
    
    public let todoIds: [String]
    public let scheduleIds: [String]
    
    public init(todoIds: [String], scheduleIds: [String]) {
        self.todoIds = todoIds
        self.scheduleIds = scheduleIds
    }
}
