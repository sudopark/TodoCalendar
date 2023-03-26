//
//  Dummies.swift
//  DomainTests
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation
import Domain

extension TodoEvent {
    
    static func dummy(_ int: Int = 0) -> TodoEvent {
        return .init(uuid: "id:\(int)", name: "name:\(int)")
    }
}

extension DoneTodoEvent {
    
    static func dummy(_ int: Int = 0) -> DoneTodoEvent {
        return .init(uuid: "did:\(int)", name: "name:\(int)", originEventId: "id:\(int)", doneTime: .now)
    }
}
