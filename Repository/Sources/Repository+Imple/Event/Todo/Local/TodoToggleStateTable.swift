//
//  TodoToggleStateTable.swift
//  Repository
//
//  Created by sudo.park on 7/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService
import Domain
import Extensions


struct TodoToggleStateTable: Table {
    
    enum Columns: String, TableColumn {
        case todoId
        case state
        
        var dataType: ColumnDataType {
            switch self {
            case .todoId: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .state: return .text([.notNull])
            }
        }
    }
    
    struct ToggleState: RowValueType {
        
        enum State: String {
            case idle
            case completing
            case reverting
        }
        
        let todoId: String
        let state: State
        
        init(todoId: String, state: State) {
            self.todoId = todoId
            self.state = state
        }
        
        init(_ cursor: CursorIterator) throws {
            self.init(
                todoId: try cursor.next().unwrap(),
                state: try .init(rawValue: try cursor.next().unwrap()).unwrap()
            )
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = ToggleState
    static var tableName: String { "TodoToggleStates"}
    
    static func scalar(_ entity: EntityType, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .todoId: return entity.todoId
        case .state: return entity.state.rawValue
        }
    }
}
