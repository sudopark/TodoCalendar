//
//  TodoItem.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


public struct TodoItem {
    
    public let uuid: String
    public var name: String
    public var isDone: Bool = false
    
    public var eventTagId: String?
    
    public var startTime: Date?
    public var endTime: Date?
    
    public init(uuid: String, name: String) {
        self.uuid = uuid
        self.name = name
    }
    
    public init(name: String) {
        self.uuid = UUID().uuidString
        self.name = name
    }
}
