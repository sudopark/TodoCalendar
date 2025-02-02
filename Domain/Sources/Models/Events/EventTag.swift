//
//  EventTag.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation
import Extensions


public enum EventTagId: Sendable, Hashable {
    case holiday
    case `default`
    case custom(String)
    
    public var customTagId: String? {
        guard case let .custom(id) = self else { return nil }
        return id
    }
}

public protocol EventTag: Sendable, Equatable {
    
    var tagId: EventTagId { get }
    var name: String { get }
    var colorHex: String { get }
}

// MARK: - default event tag

public enum DefaultEventTag: EventTag {
    case `default`(_ color: String)
    case holiday(_ color: String)
    
    public var tagId: EventTagId {
        switch self {
        case .default: return .default
        case .holiday: return .holiday
        }
    }
    
    public var name: String {
        switch self {
        case .holiday:
            return "eventTag.defaults.holiday::name".localized()
        case .default:
            return "eventTag.defaults.default::name".localized()
        }
    }
    
    public var colorHex: String {
        switch self {
        case .default(let color): return color
        case .holiday(let color): return color
        }
    }
}

// MARK: - custom event tag

public struct CustomEventTag: EventTag {
 
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
    
    public var tagId: EventTagId {
        return .custom(self.uuid)
    }
}

public struct CustomEventTagMakeParams {
    public var name: String
    public var colorHex: String
    
    public init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
    }
}

public typealias CustomEventTagEditParams = CustomEventTagMakeParams



public struct RemoveCustomEventTagWithEventsResult: Sendable {
    
    public let todoIds: [String]
    public let scheduleIds: [String]
    
    public init(todoIds: [String], scheduleIds: [String]) {
        self.todoIds = todoIds
        self.scheduleIds = scheduleIds
    }
}
