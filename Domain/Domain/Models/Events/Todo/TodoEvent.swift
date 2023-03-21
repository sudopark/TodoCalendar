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
    public var isExplicitlyDone: Bool = false
    public var isRegardAsDoneWhenTimePass: Bool = false
    
    public var eventTagId: String?
    
    public var startTime: Date?
    public var endTime: Date?
    
    public init(uuid: String, name: String) {
        self.uuid = uuid
        self.name = name
    }
}


// MARK: - Todo Event make parameters

public struct TodoEventMakeParams {
    
    public var name: String?
    public var isRegardAsDoneWhenTimePass: Bool = false
    public var eventTagId: String?
    public var startTime: Date?
    public var endTime: Date?
    
    public init() { }
}
