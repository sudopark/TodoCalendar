//
//  GoogleCalendarTables.swift
//  Repository
//
//  Created by sudo.park on 2/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import SQLiteService


// MARK: - Colors

struct GoogleCalendarColorsTable: Table {
    
    enum Columns: String, TableColumn {
        case colorType = "color_type"
        case colorKey = "color_key"
        case background
        case foreground
        
        var dataType: ColumnDataType {
            switch self {
            case .colorType: return .text([.notNull])
            case .colorKey: return .text([.notNull])
            case .background: return .text([.notNull])
            case .foreground: return .text([.notNull])
            }
        }
    }
    
    struct Entity: RowValueType {
        let colorType: String
        let colorKey: String
        let background: String
        let foreground: String
        
        init(calendar key: String, _ colorSet: GoogleCalendarColors.ColorSet) {
            self.colorType = "calendar"
            self.colorKey = key
            self.background = colorSet.backgroudHex
            self.foreground = colorSet.foregroundHex
        }
        
        init(event key: String, _ colorSet: GoogleCalendarColors.ColorSet) {
            self.colorType = "event"
            self.colorKey = key
            self.background = colorSet.backgroudHex
            self.foreground = colorSet.foregroundHex
        }
        
        init(_ cursor: CursorIterator) throws {
            self.colorType = try cursor.next().unwrap()
            self.colorKey = try cursor.next().unwrap()
            self.background = try cursor.next().unwrap()
            self.foreground = try cursor.next().unwrap()
        }
    }
    
    typealias EntityType = Entity
    
    typealias ColumnType = Columns
    
    static let tableName: String = "google_calendar_colors"
    
    static func scalar(_ entity: Entity, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .colorType: return entity.colorType
        case .colorKey: return entity.colorKey
        case .background: return entity.background
        case .foreground: return entity.foreground
        }
    }
}
