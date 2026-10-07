//
//  CustomColorThemeRemoteRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 10/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


public final class CustomColorThemeRemoteRepositoryImple: CustomColorThemeRepository {

    private let remote: any RemoteAPI
    private let cacheStorage: any CustomColorThemeLocalStorage

    public init(
        remote: any RemoteAPI,
        cacheStorage: any CustomColorThemeLocalStorage
    ) {
        self.remote = remote
        self.cacheStorage = cacheStorage
    }
}


extension CustomColorThemeRemoteRepositoryImple {

    public func loadThemes() async throws -> [CustomColorTheme] {
        let refreshed: [CustomColorTheme]
        do {
            refreshed = try await self.loadThemesFromRemote()
        } catch {
            return try await self.cacheStorage.fetchThemes()
        }
        await self.replaceCached(with: refreshed)
        return refreshed
    }

    private func loadThemesFromRemote() async throws -> [CustomColorTheme] {
        let mappers: [CustomColorThemeRemoteMapper] = try await self.remote.request(
            .get,
            AppSettingEndpoints.colorThemes
        )
        return mappers.map { $0.theme }.sorted { $0.createdAt < $1.createdAt }
    }

    private func replaceCached(with refreshed: [CustomColorTheme]) async {
        let cached = (try? await self.cacheStorage.fetchThemes()) ?? []
        let refreshedIds = Set(refreshed.map { $0.uuid })
        await cached.filter { !refreshedIds.contains($0.uuid) }.asyncForEach {
            try? await self.cacheStorage.removeTheme($0.uuid)
        }
        await refreshed.asyncForEach {
            try? await self.cacheStorage.saveTheme($0)
        }
    }

    public func fetchTheme(_ uuid: String) async throws -> CustomColorTheme? {
        return try await self.cacheStorage.fetchTheme(uuid)
    }

    public func saveTheme(_ theme: CustomColorTheme) async throws {
        let saved: CustomColorThemeRemoteMapper = try await self.remote.request(
            .put,
            AppSettingEndpoints.colorTheme(uuid: theme.uuid),
            parameters: theme.asJson()
        )
        try? await self.cacheStorage.saveTheme(saved.theme)
    }

    public func removeTheme(_ uuid: String) async throws {
        _ = try await self.remote.request(
            .delete,
            AppSettingEndpoints.colorTheme(uuid: uuid),
            with: nil,
            parameters: [:]
        )
        try? await self.cacheStorage.removeTheme(uuid)
    }
}
