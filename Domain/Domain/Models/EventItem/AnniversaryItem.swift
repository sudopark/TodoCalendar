//
//  Anniversary.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


public struct AnniversaryItem {
    
    public let uuid: String
    public var name: String
    public var turn: Int?
    
    public var eventTagId: String?
    
    public let scheduleTime: Date
    public var endTime: Date?
    
    public init(uuid: String, name: String, scheduleTime: Date) {
        self.uuid = uuid
        self.name = name
        self.scheduleTime = scheduleTime
    }
    
    public init(name: String, scheduleTime: Date) {
        self.uuid = UUID().uuidString
        self.name = name
        self.scheduleTime = scheduleTime
    }
}
