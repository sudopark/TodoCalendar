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
    
    public var isValidForUpdate: Bool {
        return self.name?.isEmpty == false
            || self.eventTagId?.isEmpty == false
            || self.time != nil
            || self.repeating != nil
    }
}

public typealias TodoEditParams = TodoMakeParams
