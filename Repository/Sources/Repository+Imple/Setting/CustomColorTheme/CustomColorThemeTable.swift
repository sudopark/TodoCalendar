//
//  CustomColorThemeTable.swift
//  Repository
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros
import Domain


typealias CustomColorThemeTable = CustomColorThemeTableV0

@Table("CustomColorThemes")
struct CustomColorThemeTableV0 {

    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    let uuid: String

    @Column(.notNull)
    let name: String

    @Column(.notNull, name: "schema_version")
    let schemaVersion: Int

    @Column(.notNull)
    var seeds: String?

    @Column(.notNull)
    var colors: String?

    @Column(.notNull, name: "created_at")
    let createdAt: Double

    @Column(.notNull, name: "updated_at")
    let updatedAt: Double
}


// MARK: - CustomColorTheme 변환

extension CustomColorThemeTable.Entity {

    init(_ theme: CustomColorTheme) {
        let mapper = CustomColorThemeJSONMapper()
        self.init(
            uuid: theme.uuid,
            name: theme.name,
            schemaVersion: theme.schemaVersion,
            seeds: try? mapper.encodeSeeds(theme.seeds),
            colors: try? mapper.encodeColors(theme.colors),
            createdAt: theme.createdAt,
            updatedAt: theme.updatedAt
        )
    }

    func asCustomColorTheme() throws -> CustomColorTheme {
        let mapper = CustomColorThemeJSONMapper()
        let seedsText: String = try self.seeds.unwrap()
        let colorsText: String = try self.colors.unwrap()
        return CustomColorTheme(
            uuid: self.uuid,
            name: self.name,
            schemaVersion: self.schemaVersion,
            seeds: try mapper.decodeSeeds(seedsText),
            colors: try mapper.decodeColors(colorsText),
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
}
