//
//  KeyValueTable.swift
//  Repository
//
//  Created by sudo.park on 12/6/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService


enum KeyValueTableKeys: String {
    case fcmToken = "fcm_token"
}

struct KeyValueTable: Table {
    
    struct Entity: RowValueType {
        let key: String
        var value: String?
        
        init(_ key: KeyValueTableKeys, value: String? = nil) {
            self.key = key.rawValue
            self.value = value
        }
        
        init(key: String, value: String? = nil) {
            self.key = key
            self.value = value
        }
        
        init(_ cursor: CursorIterator) throws {
            self.key = try cursor.next().unwrap()
            self.value = cursor.next()
        }
    }
    
    enum Columns: String, TableColumn {
        case key
        case value
        
        var dataType: ColumnDataType {
            switch self {
            case .key:
                return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .value:
                return .text([])
            }
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = Entity
    static var tableName: String { "KeyValues" }
    
    static func scalar(_ entity: Entity, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .key: return entity.key
        case .value: return entity.value
        }
    }
}
