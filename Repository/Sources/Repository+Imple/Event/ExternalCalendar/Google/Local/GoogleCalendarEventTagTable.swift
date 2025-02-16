//
//  GoogleCalendarEventTagTable.swift
//  Repository
//
//  Created by sudo.park on 2/17/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import SQLiteService

extension GoogleCalendarEventTag: @retroactive RowValueType {
    
    public init(_ cursor: CursorIterator) throws {
        self.init(
            id: try cursor.next().unwrap(),
            name: try cursor.next().unwrap()
        )
        self.description = cursor.next()
        self.backgroundColorHex = cursor.next()
        self.foregroundColorHex = cursor.next()
        self.colorId = cursor.next()
    }
}

struct GoogleCalendarEventTagTable: Table {
    
    enum Columns: String, TableColumn {
        case tagId = "tag_id"
        case name
        case description
        case background
        case foreground
        case colorId = "color_id"
        
        var dataType: ColumnDataType {
            switch self {
            case .tagId: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .name: return .text([.notNull])
            case .description: return .text([])
            case .background: return .text([])
            case .foreground: return .text([])
            case .colorId: return .text([])
            }
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = GoogleCalendarEventTag
    static let tableName: String = "google_calendar_list"
    
    static func scalar(_ entity: GoogleCalendarEventTag, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .tagId: return entity.id
        case .name: return entity.name
        case .description: return entity.description
        case .background: return entity.backgroundColorHex
        case .foreground: return entity.foregroundColorHex
        case .colorId: return entity.colorId
        }
    }
}
