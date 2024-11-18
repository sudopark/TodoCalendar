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

public struct TodoEvent: Sendable, Equatable {
    
    public let uuid: String
    public var name: String
    public var creatTimeStamp: TimeInterval?
    
    public var eventTagId: AllEventTagId?
    
    public var time: EventTime?
    public var repeating: EventRepeating?
    
    public var notificationOptions: [EventNotificationTimeOption] = []
    
    public init(uuid: String, name: String) {
        self.uuid = uuid
        self.name = name
    }
    
    public init?(_ params: TodoMakeParams) {
        guard let name = params.name
        else { return nil }
        self.uuid = UUID().uuidString
        self.name = name
        self.creatTimeStamp = Date().timeIntervalSince1970
        self.eventTagId = params.eventTagId
        self.time = params.time
        self.repeating = params.repeating
        self.notificationOptions = params.notificationOptions ?? []
    }
    
    public func apply(_ params: TodoEditParams) -> TodoEvent {
        return self
            |> \.name .~ (params.name ?? self.name)
            |> \.eventTagId .~ params.eventTagId
            |> \.time .~ params.time
            |> \.repeating .~ params.repeating
            |> \.notificationOptions .~ (params.notificationOptions ?? self.notificationOptions)
    }
    
    public func applyIfNotNil(_ params: TodoEditParams) -> TodoEvent {
        var sender = self
        if let name = params.name {
            sender.name = name
        }
        if let eventTagId = params.eventTagId {
            sender.eventTagId = eventTagId
        }
        if let time = params.time {
            sender.time = time
        }
        if let repeating = params.repeating {
            sender.repeating = repeating
        }
        if let notificationOptions = params.notificationOptions {
            sender.notificationOptions = notificationOptions
        }
        return sender
    }
}


// MARK: - Todo make parameters

public struct TodoMakeParams: Sendable {
    
    public var name: String?
    public var eventTagId: AllEventTagId?
    public var time: EventTime?
    public var repeating: EventRepeating?
    public var notificationOptions: [EventNotificationTimeOption]?
    
    public init() { }
    
    public var isValidForMaking: Bool {
        return self.name?.isEmpty == false
    }
    
    public init(_ todo: TodoEvent) {
        self.name = todo.name
        self.eventTagId = todo.eventTagId
        self.time = todo.time
        self.notificationOptions = todo.notificationOptions
    }
}

public struct TodoEditParams: Sendable, Equatable {
    
    public enum RepeatingUpdateScope: Equatable, Sendable {
        case all
        case onlyThisTime
    }
    public enum EditMethod: Equatable, Sendable {
        case put
        case patch
    }
    public let editMethod: EditMethod
    public var name: String?
    public var eventTagId: AllEventTagId?
    public var time: EventTime?
    public var repeating: EventRepeating?
    public var repeatingUpdateScope: RepeatingUpdateScope?
    public var notificationOptions: [EventNotificationTimeOption]?
    
    public init(_ editMethod: EditMethod) {
        self.editMethod = editMethod
    }
    
    public func asMakeParams() -> TodoMakeParams {
        return TodoMakeParams()
            |> \.name .~ (self.name)
            |> \.eventTagId .~ self.eventTagId
            |> \.time .~ self.time
            |> \.repeating .~ self.repeating
            |> \.notificationOptions .~ self.notificationOptions
    }
    
    public var isValidForUpdate: Bool {
        switch self.editMethod {
        case .put:
            return self.name?.isEmpty == false
        case .patch:
            return self.name?.isEmpty == false
                || self.eventTagId != nil
                || self.time != nil
                || self.repeating != nil
                || self.notificationOptions != nil
        }
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


public struct RemoveTodoResult {
    
    public var nextRepeatingTodo: TodoEvent?
    public init() { }
}

public enum TodoTogglingState {
    
    case idle(target: TodoEvent)
    case completing(origin: TodoEvent, doneId: String?)
    case reverting
}

public enum TodoToggleResult {
    case completed(DoneTodoEvent)
    case reverted(TodoEvent)
    
    public var isToggledCurrentTodo: Bool {
        switch self {
        case .completed(let done): return done.eventTime == nil
        case .reverted(let todo): return todo.time == nil
        }
    }
}


// MARK: - skip todo

public enum SkipTodoParams {
    case next
    case until(EventTime)
}
