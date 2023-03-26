//
//  TodoEvent.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


// MARK: - Todo Evnet

public struct TodoEvent {
    
    public let uuid: String
    public var name: String
    public var isDone: Bool = false
    public var shouldBeExplicitlyDone: Bool = false
    
    public var eventTagId: String?
    
    public var time: EventTime?
    public var repeating: EventRepeating?
    public var exceptFromRepeatedEventId: String?
    
    public init(uuid: String, name: String) {
        self.uuid = uuid
        self.name = name
    }
}


// MARK: - Todo make parameters

public struct TodoMakeParams {
    
    public var name: String?
    public var shouldBeExplicitlyDone: Bool = false
    public var eventTagId: String?
    public var time: EventTime?
    public var repeating: EventRepeating?
    public var exceptFromRepeatedScheduleId: String?
    
    public init() { }
}

public typealias TodoEditParams = TodoMakeParams
