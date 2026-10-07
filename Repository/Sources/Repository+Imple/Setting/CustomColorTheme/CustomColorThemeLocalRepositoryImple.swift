//
//  CustomColorThemeLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public final class CustomColorThemeLocalRepositoryImple: CustomColorThemeRepository {

    private let localStorage: any CustomColorThemeLocalStorage

    public init(localStorage: any CustomColorThemeLocalStorage) {
        self.localStorage = localStorage
    }
}


extension CustomColorThemeLocalRepositoryImple {

    public func loadThemes() async throws -> [CustomColorTheme] {
        return try await self.localStorage.fetchThemes()
    }

    public func fetchTheme(_ uuid: String) async throws -> CustomColorTheme? {
        return try await self.localStorage.fetchTheme(uuid)
    }

    public func saveTheme(_ theme: CustomColorTheme) async throws {
        try await self.localStorage.saveTheme(theme)
    }

    public func removeTheme(_ uuid: String) async throws {
        try await self.localStorage.removeTheme(uuid)
    }
}
