//
//  CustomEventTagTable.swift
//  Repository
//
//  Created by sudo.park on 2023/05/28.
//

import Foundation
import SQLiteService
import Domain
import Extensions

struct CustomEventTagTable: Table {
    
    enum Columns: String, TableColumn {
        case uuid
        case name
        case colorHex
        
        var dataType: ColumnDataType {
            switch self {
            case .uuid: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .name: return .text([.unique, .notNull])
            case .colorHex: return .text([.notNull])
            }
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = CustomEventTag
    static var tableName: String { "EventTags" }
    
    static func scalar(_ entity: EntityType, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .uuid: return entity.uuid
        case .name: return entity.name
        case .colorHex: return entity.colorHex
        }
    }
}

extension CustomEventTag: RowValueType {
    
    public init(_ cursor: CursorIterator) throws {
        self.init(
            uuid: try cursor.next().unwrap(),
            name: try cursor.next().unwrap(),
            colorHex: try cursor.next().unwrap()
        )
    }
}
