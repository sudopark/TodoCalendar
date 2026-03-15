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

extension GoogleCalendar.Tag: @retroactive RowValueType {
    
    public init(_ cursor: CursorIterator) throws {
        self.init(
            id: try cursor.next().unwrap(),
            name: try cursor.next().unwrap()
        )
        self.description = cursor.next()
        self.backgroundColorHex = cursor.next()
        self.foregroundColorHex = cursor.next()
        self.colorId = cursor.next()
        self.isSelected = cursor.next()
    }
}

// MARK: - Old EventTag (공통DB 레거시 테이블)

struct OldGoogleCalendarEventTagTable: Table {

    enum Columns: String, TableColumn {
        case tagId = "tag_id"
        case name
        case description
        case background
        case foreground
        case colorId = "color_id"
        case isSelected = "is_selected"

        var dataType: ColumnDataType {
            switch self {
            case .tagId: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .name: return .text([.notNull])
            case .description: return .text([])
            case .background: return .text([])
            case .foreground: return .text([])
            case .colorId: return .text([])
            case .isSelected: return .integer([])
            }
        }
    }

    typealias ColumnType = Columns
    typealias EntityType = GoogleCalendar.Tag
    static let tableName: String = "google_calendar_list"

    static func scalar(_ entity: GoogleCalendar.Tag, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .tagId: return entity.id
        case .name: return entity.name
        case .description: return entity.description
        case .background: return entity.backgroundColorHex
        case .foreground: return entity.foregroundColorHex
        case .colorId: return entity.colorId
        case .isSelected: return entity.isSelected ?? false
        }
    }

    static func migrateStatement(for version: Int32) -> String? {
        switch version {
        case 2:
            return Self.addColumnStatement(.isSelected)
        default: return nil
        }
    }
}


// MARK: - EventTag (google_calendar.db 신규 테이블, accountId 포함)

struct GoogleCalendarEventTagTable: Table {

    enum Columns: String, TableColumn {
        case accountId = "account_id"
        case tagId = "tag_id"
        case name
        case description
        case background
        case foreground
        case colorId = "color_id"
        case isSelected = "is_selected"

        var dataType: ColumnDataType {
            switch self {
            case .accountId: return .text([.notNull])
            case .tagId: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .name: return .text([.notNull])
            case .description: return .text([])
            case .background: return .text([])
            case .foreground: return .text([])
            case .colorId: return .text([])
            case .isSelected: return .integer([])
            }
        }
    }

    struct Entity: RowValueType {
        let accountId: String
        let tag: GoogleCalendar.Tag

        init(accountId: String, _ tag: GoogleCalendar.Tag) {
            self.accountId = accountId
            self.tag = tag
        }

        init(_ cursor: CursorIterator) throws {
            self.accountId = try cursor.next().unwrap()
            self.tag = try GoogleCalendar.Tag(cursor)
        }
    }

    typealias ColumnType = Columns
    typealias EntityType = Entity
    static let tableName: String = "google_calendar_list"

    static func scalar(_ entity: Entity, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .accountId: return entity.accountId
        case .tagId: return entity.tag.id
        case .name: return entity.tag.name
        case .description: return entity.tag.description
        case .background: return entity.tag.backgroundColorHex
        case .foreground: return entity.tag.foregroundColorHex
        case .colorId: return entity.tag.colorId
        case .isSelected: return entity.tag.isSelected ?? false
        }
    }
}
