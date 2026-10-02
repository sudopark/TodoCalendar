//
//  CustomColorThemeTable.swift
//  Repository
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService
import Domain


struct CustomColorThemeTable: Table {

    enum Columns: String, TableColumn {
        case uuid
        case name
        case schemaVersion = "schema_version"
        case seeds
        case colors
        case createdAt = "created_at"
        case updatedAt = "updated_at"

        var dataType: ColumnDataType {
            switch self {
            case .uuid: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .name: return .text([.notNull])
            case .schemaVersion: return .integer([.notNull])
            case .seeds: return .text([.notNull])
            case .colors: return .text([.notNull])
            case .createdAt: return .real([.notNull])
            case .updatedAt: return .real([.notNull])
            }
        }
    }

    typealias ColumnType = Columns
    typealias EntityType = CustomColorTheme
    static var tableName: String { "CustomColorThemes" }

    static func scalar(_ entity: CustomColorTheme, for column: Columns) -> (any ScalarType)? {
        let mapper = CustomColorThemeJSONMapper()
        switch column {
        case .uuid: return entity.uuid
        case .name: return entity.name
        case .schemaVersion: return entity.schemaVersion
        case .seeds: return try? mapper.encodeSeeds(entity.seeds)
        case .colors: return try? mapper.encodeColors(entity.colors)
        case .createdAt: return entity.createdAt
        case .updatedAt: return entity.updatedAt
        }
    }
}


extension CustomColorTheme: @retroactive RowValueType {

    public init(_ cursor: CursorIterator) throws {
        let mapper = CustomColorThemeJSONMapper()
        let uuid: String = try cursor.next().unwrap()
        let name: String = try cursor.next().unwrap()
        let schemaVersion: Int = try cursor.next().unwrap()
        let seedsText: String = try cursor.next().unwrap()
        let colorsText: String = try cursor.next().unwrap()
        self.init(
            uuid: uuid,
            name: name,
            schemaVersion: schemaVersion,
            seeds: try mapper.decodeSeeds(seedsText),
            colors: try mapper.decodeColors(colorsText),
            createdAt: try cursor.next().unwrap(),
            updatedAt: try cursor.next().unwrap()
        )
    }
}
