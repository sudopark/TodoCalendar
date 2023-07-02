//
//  Dummies.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/07/02.
//

import Foundation
import Domain

extension TimeStamp {
    
    public static func dummy(_ int: Int = 0) -> TimeStamp {
        return .init(TimeInterval(int), timeZone: "UTC")
    }
}

extension TodoEvent {
    
    public static func dummy(_ int: Int = 0) -> TodoEvent {
        return .init(uuid: "id:\(int)", name: "name:\(int)")
    }
}

extension DoneTodoEvent {
    
    public static func dummy(_ int: Int = 0) -> DoneTodoEvent {
        return .init(uuid: "did:\(int)", name: "name:\(int)", originEventId: "id:\(int)", doneTime: .now)
    }
}

