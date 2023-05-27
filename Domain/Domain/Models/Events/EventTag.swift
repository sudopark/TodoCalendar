//
//  EventTag.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


public struct EventTag {
    
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
    public var colorHext: String
    
    public init(name: String, colorHex: String) {
        self.name = name
        self.colorHext = colorHex
    }
}

public typealias EventTagEditParams = EventTagMakeParams
