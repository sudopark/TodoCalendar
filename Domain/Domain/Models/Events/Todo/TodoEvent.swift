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
}


// MARK: - Todo make parameters

public struct TodoMakeParams {
    
    public var name: String?
    public var eventTagId: String?
    public var time: EventTime?
    public var repeating: EventRepeating?
    
    public init() { }
    
    public var isValidForMaking: Bool {
        return self.name?.isEmpty == false
    }
}

public struct TodoEditParams {
    
    public enum RepeatingUpdateScope: Equatable {
        case all
        case onlyThisTime
    }
    public var name: String?
    public var eventTagId: String?
    public var time: EventTime?
    public var repeating: EventRepeating?
    public var repeatingUpdateScope: RepeatingUpdateScope?
    
    public var isValidForUpdate: Bool {
        switch self.repeatingUpdateScope {
        case .onlyThisTime:
            return self.name?.isEmpty == false
            
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
