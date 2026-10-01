//
//  TodoToggleStateTable.swift
//  Repository
//
//  Created by sudo.park on 7/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros
import Domain
import Extensions


typealias TodoToggleStateTable = TodoToggleStateTableV0

@Table("TodoToggleStates")
struct TodoToggleStateTableV0 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    let todoId: String
    
    @Column(.notNull)
    var state: String
}


// MARK: - State 변환

extension TodoToggleStateTable {
    
    enum State: String {
        case idle
        case completing
        case reverting
    }
}

extension TodoToggleStateTable.Entity {
    
    init(todoId: String, state: TodoToggleStateTable.State) {
        self.init(todoId: todoId, state: state.rawValue)
    }
    
    func asState() throws -> TodoToggleStateTable.State {
        return try TodoToggleStateTable.State(rawValue: self.state).unwrap()
    }
}
