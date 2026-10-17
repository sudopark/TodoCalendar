//
//  StubCustomColorThemeRepository.swift
//  DomainTests
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions

@testable import Domain


final class StubCustomColorThemeRepository: CustomColorThemeRepository, @unchecked Sendable {

    private let themes: [CustomColorTheme]
    private let shouldFailLoad: Bool
    private let shouldFailSave: Bool
    private let shouldFailRemove: Bool

    init(
        themes: [CustomColorTheme] = [],
        shouldFailLoad: Bool = false,
        shouldFailSave: Bool = false,
        shouldFailRemove: Bool = false
    ) {
        self.themes = themes
        self.shouldFailLoad = shouldFailLoad
        self.shouldFailSave = shouldFailSave
        self.shouldFailRemove = shouldFailRemove
    }

    private(set) var didSavedThemes: [CustomColorTheme] = []
    private(set) var didRemovedUuids: [String] = []

    func loadThemes() async throws -> [CustomColorTheme] {
        guard self.shouldFailLoad == false else { throw RuntimeError("load failed") }
        return self.themes
    }

    func fetchTheme(_ uuid: String) async throws -> CustomColorTheme? {
        guard self.shouldFailLoad == false else { throw RuntimeError("load failed") }
        return self.themes.first { $0.uuid == uuid }
    }

    func saveTheme(_ theme: CustomColorTheme) async throws {
        guard self.shouldFailSave == false else { throw RuntimeError("save failed") }
        self.didSavedThemes.append(theme)
    }

    func removeTheme(_ uuid: String) async throws {
        guard self.shouldFailRemove == false else { throw RuntimeError("remove failed") }
        self.didRemovedUuids.append(uuid)
    }
}
