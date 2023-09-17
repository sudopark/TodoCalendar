//
//  TodoEvent.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation
import Prelude
import Optics


// MARK: - Todo Evnet

public struct TodoEvent {
    
    public let uuid: String
    public var name: String
    
    public var eventTagId: String?
    
    public var time: EventTime?
    public var repeating: EventRepeating?
    
    public init(uuid: String, name: String) {
        self.uuid = uuid
        self.name = name
    }
    
    public init?(_ params: TodoMakeParams) {
        guard let name = params.name
        else { return nil }
        self.uuid = UUID().uuidString
        self.name = name
        self.eventTagId = params.eventTagId
        self.time = params.time
        self.repeating = params.repeating
    }
    
    public func apply(_ params: TodoEditParams) -> TodoEvent {
        return self
            |> \.name .~ (params.name ?? self.name)
            |> \.eventTagId .~ params.eventTagId
            |> \.time .~ params.time
            |> \.repeating .~ params.repeating
    }
}


// MARK: - Todo make parameters

public struct TodoMakeParams: Sendable {
    
    public var name: String?
    public var eventTagId: String?
    public var time: EventTime?
    public var repeating: EventRepeating?
    
    public init() { }
    
    public var isValidForMaking: Bool {
        return self.name?.isEmpty == false
    }
}

public struct TodoEditParams: Sendable {
    
    public enum RepeatingUpdateScope: Equatable, Sendable {
        case all
        case onlyThisTime
    }
    public var name: String?
    public var eventTagId: String?
    public var time: EventTime?
    public var repeating: EventRepeating?
    public var repeatingUpdateScope: RepeatingUpdateScope?
    
    public init() { }
    
    public var isValidForUpdate: Bool {
        switch self.repeatingUpdateScope {
        case .onlyThisTime:
            return self.asMakeParams().isValidForMaking
            
        default:
            return self.name?.isEmpty == false
                || self.eventTagId?.isEmpty == false
                || self.time != nil
                || self.repeating != nil
        }
    }
    
    public func asMakeParams() -> TodoMakeParams {
        return TodoMakeParams()
            |> \.name .~ (self.name)
            |> \.eventTagId .~ self.eventTagId
            |> \.time .~ self.time
            |> \.repeating .~ self.repeating
    }
}


// MARK: - replace

public struct ReplaceRepeatingTodoEventResult {
    
    public let newTodoEvent: TodoEvent
    public var nextRepeatingTodoEvent: TodoEvent?
    
    public init(newTodoEvent: TodoEvent) {
        self.newTodoEvent = newTodoEvent
    }
}
