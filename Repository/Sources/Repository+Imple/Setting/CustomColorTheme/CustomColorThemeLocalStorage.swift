//
//  CustomColorThemeLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService
import Domain


public protocol CustomColorThemeLocalStorage: AnyObject, Sendable {

    func fetchThemes() async throws -> [CustomColorTheme]
    func fetchTheme(_ uuid: String) async throws -> CustomColorTheme?
    func saveTheme(_ theme: CustomColorTheme) async throws
    func removeTheme(_ uuid: String) async throws
    func removeThemes(_ uuids: [String]) async throws
}


public final class CustomColorThemeLocalStorageImple: CustomColorThemeLocalStorage {

    private let sqliteService: SQLiteService

    public init(sqliteService: SQLiteService) {
        self.sqliteService = sqliteService
    }
}


extension CustomColorThemeLocalStorageImple {

    public func fetchThemes() async throws -> [CustomColorTheme] {
        return try await self.sqliteService.async.run { db -> [CustomColorTheme] in
            try? db.createTableOrNot(CustomColorThemeTable.self)
            let query = CustomColorThemeTable.selectAll()
                .orderBy(isAscending: true) { $0.createdAt }
            return try db.load(CustomColorThemeTable.self, query: query)
                .map { try $0.asCustomColorTheme() }
        }
    }

    public func fetchTheme(_ uuid: String) async throws -> CustomColorTheme? {
        return try await self.sqliteService.async.run { db -> CustomColorTheme? in
            try? db.createTableOrNot(CustomColorThemeTable.self)
            let query = CustomColorThemeTable.selectAll().where { $0.uuid == uuid }
            return try db.load(CustomColorThemeTable.self, query: query)
                .first?.asCustomColorTheme()
        }
    }

    public func saveTheme(_ theme: CustomColorTheme) async throws {
        try await self.sqliteService.async.run { db in
            try? db.createTableOrNot(CustomColorThemeTable.self)
            try db.insertOne(
                CustomColorThemeTable.self,
                entity: CustomColorThemeTable.Entity(theme),
                shouldReplace: true
            )
        }
    }

    public func removeTheme(_ uuid: String) async throws {
        try await self.sqliteService.async.run { db in
            try? db.createTableOrNot(CustomColorThemeTable.self)
            let query = CustomColorThemeTable.delete().where { $0.uuid == uuid }
            try db.delete(CustomColorThemeTable.self, query: query)
        }
    }

    public func removeThemes(_ uuids: [String]) async throws {
        try await self.sqliteService.async.run { db in
            try? db.createTableOrNot(CustomColorThemeTable.self)
            let query = CustomColorThemeTable.delete().where { $0.uuid.in(uuids) }
            try db.delete(CustomColorThemeTable.self, query: query)
        }
    }
}
