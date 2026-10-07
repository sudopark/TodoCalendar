//
//  CustomColorThemeRemoteRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 10/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain
import Extensions

@testable import Repository


struct CustomColorThemeRemoteRepositoryImpleTests {

    private func makeRepository(
        responses: [StubRemoteAPI.Response] = DummyResponse().responses,
        cached: [CustomColorTheme] = [],
        shouldFailFetchCache: Bool = false
    ) -> (CustomColorThemeRemoteRepositoryImple, StubRemoteAPI, SpyCustomColorThemeLocalStorage) {
        let remote = StubRemoteAPI(responses: responses)
        let storage = SpyCustomColorThemeLocalStorage(themes: cached, shouldFailFetch: shouldFailFetchCache)
        let repository = CustomColorThemeRemoteRepositoryImple(remote: remote, cacheStorage: storage)
        return (repository, remote, storage)
    }

    private func makeTheme(
        _ uuid: String,
        createdAt: TimeInterval,
        seeds: CustomColorThemeSeeds = CustomColorThemeSeeds(background: "#000000", accent: "#FFFFFF", form: .filled)
    ) -> CustomColorTheme {
        return CustomColorTheme(
            uuid: uuid,
            name: "cached_\(uuid)",
            schemaVersion: 1,
            seeds: seeds,
            colors: [:],
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}


// MARK: - load

extension CustomColorThemeRemoteRepositoryImpleTests {

    @Test func loadThemes_returnsRemoteThemesSortedByCreatedAt() async throws {
        // given
        let (repository, _, _) = self.makeRepository()

        // when
        let themes = try await repository.loadThemes()

        // then
        #expect(themes.map { $0.uuid } == ["early", "late"])
        let early = try #require(themes.first)
        #expect(early.name == "바다")
        #expect(early.schemaVersion == 1)
        #expect(early.seeds.background == "#F4F1EA")
        #expect(early.seeds.accent == "#2B6CB0")
        #expect(early.seeds.form == .grouped)
        #expect(early.seeds.ai == "#ABCDEF")
        #expect(early.seeds.text == nil)
        #expect(early.colors == ["bg0": "#F4F1EA"])
        #expect(early.createdAt == 100)
        #expect(early.updatedAt == 150)
    }

    @Test func loadThemes_replacesCacheWithRemoteThemes() async throws {
        // given
        let (repository, _, storage) = self.makeRepository(
            cached: [self.makeTheme("only_cached", createdAt: 10), self.makeTheme("late", createdAt: 300)]
        )

        // when
        _ = try await repository.loadThemes()

        // then
        let cached = try await storage.fetchThemes()
        #expect(cached.map { $0.uuid } == ["early", "late"])
        #expect(cached.last?.name == "산")
        #expect(storage.didRemovedThemeIds == ["only_cached"])
    }

    @Test func loadThemes_whenRemoteFails_returnsCachedThemes() async throws {
        // given
        let (repository, _, storage) = self.makeRepository(
            responses: DummyResponse().failResponses,
            cached: [self.makeTheme("cached", createdAt: 10)]
        )

        // when
        let themes = try await repository.loadThemes()

        // then
        #expect(themes.map { $0.uuid } == ["cached"])
        #expect(storage.didSavedThemes.isEmpty)
        #expect(storage.didRemovedThemeIds.isEmpty)
    }

    @Test func loadThemes_whenRemoteResponseMissesRequiredSeed_returnsCachedThemes() async throws {
        // given
        let (repository, _, storage) = self.makeRepository(
            responses: DummyResponse().missingRequiredSeedResponses,
            cached: [self.makeTheme("cached", createdAt: 10)]
        )

        // when
        let themes = try await repository.loadThemes()

        // then
        #expect(themes.map { $0.uuid } == ["cached"])
        #expect(storage.didSavedThemes.isEmpty)
        #expect(storage.didRemovedThemeIds.isEmpty)
    }

    @Test func loadThemes_whenRemoteAndCacheFail_throws() async throws {
        // given
        let (repository, _, _) = self.makeRepository(
            responses: DummyResponse().failResponses,
            shouldFailFetchCache: true
        )

        // when + then
        await #expect(throws: (any Error).self) {
            try await repository.loadThemes()
        }
    }

    @Test func fetchTheme_readsCacheOnly() async throws {
        // given
        let (repository, remote, _) = self.makeRepository(
            cached: [self.makeTheme("cached", createdAt: 10)]
        )

        // when
        let theme = try await repository.fetchTheme("cached")
        let missing = try await repository.fetchTheme("early")

        // then
        #expect(theme?.uuid == "cached")
        #expect(missing == nil)
        #expect(remote.didRequestedPath == nil)
    }
}


// MARK: - save

extension CustomColorThemeRemoteRepositoryImpleTests {

    @Test func saveTheme_putsThemeBodyAndCachesResponse() async throws {
        // given
        let (repository, remote, storage) = self.makeRepository()
        let seeds = CustomColorThemeSeeds(background: "#000000", accent: "#FFFFFF", form: .filled)
            |> \.ai .~ "#ABCDEF"
        let theme = self.makeTheme("early", createdAt: 100, seeds: seeds)

        // when
        try await repository.saveTheme(theme)

        // then
        #expect(remote.didRequestedMethod == .put)
        #expect(remote.didRequestedPath?.hasSuffix("/v2/setting/color_themes/early") == true)
        let params = try #require(remote.didRequestedParams)
        #expect(params["uuid"] as? String == "early")
        #expect(params["name"] as? String == "cached_early")
        #expect(params["schema_version"] as? Int == 1)
        #expect(params["seeds"] as? [String: String] == [
            "background": "#000000", "accent": "#FFFFFF", "form": "filled", "ai": "#ABCDEF"
        ])
        #expect(params["colors"] as? [String: String] == [:])
        #expect(params["created_at"] as? TimeInterval == 100)
        #expect(params["updated_at"] as? TimeInterval == 100)
        #expect(storage.didSavedThemes.map { $0.name } == ["바다"])
    }

    @Test func saveTheme_whenRemoteFails_throwsAndKeepsCache() async throws {
        // given
        let (repository, _, storage) = self.makeRepository(responses: DummyResponse().failResponses)

        // when
        await #expect(throws: (any Error).self) {
            try await repository.saveTheme(self.makeTheme("early", createdAt: 100))
        }

        // then
        #expect(storage.didSavedThemes.isEmpty)
    }
}


// MARK: - remove

extension CustomColorThemeRemoteRepositoryImpleTests {

    @Test func removeTheme_deletesRemoteAndCache() async throws {
        // given
        let (repository, remote, storage) = self.makeRepository(
            cached: [self.makeTheme("early", createdAt: 100)]
        )

        // when
        try await repository.removeTheme("early")

        // then
        #expect(remote.didRequestedMethod == .delete)
        #expect(remote.didRequestedPath?.hasSuffix("/v2/setting/color_themes/early") == true)
        #expect(storage.didRemovedThemeIds == ["early"])
        let cached = try await storage.fetchThemes()
        #expect(cached.isEmpty)
    }

    @Test func removeTheme_whenRemoteFails_throwsAndKeepsCache() async throws {
        // given
        let (repository, _, storage) = self.makeRepository(
            responses: DummyResponse().failResponses,
            cached: [self.makeTheme("early", createdAt: 100)]
        )

        // when
        await #expect(throws: (any Error).self) {
            try await repository.removeTheme("early")
        }

        // then
        #expect(storage.didRemovedThemeIds.isEmpty)
        let cached = try await storage.fetchThemes()
        #expect(cached.map { $0.uuid } == ["early"])
    }
}


// MARK: - doubles

private final class SpyCustomColorThemeLocalStorage: CustomColorThemeLocalStorage, @unchecked Sendable {

    private var themes: [String: CustomColorTheme]
    private let shouldFailFetch: Bool
    private(set) var didSavedThemes: [CustomColorTheme] = []
    private(set) var didRemovedThemeIds: [String] = []

    init(themes: [CustomColorTheme], shouldFailFetch: Bool) {
        self.themes = themes.asDictionary { $0.uuid }
        self.shouldFailFetch = shouldFailFetch
    }

    func fetchThemes() async throws -> [CustomColorTheme] {
        guard self.shouldFailFetch == false
        else { throw RuntimeError("fetch failed") }
        return self.themes.values.sorted { $0.createdAt < $1.createdAt }
    }

    func fetchTheme(_ uuid: String) async throws -> CustomColorTheme? {
        return self.themes[uuid]
    }

    func saveTheme(_ theme: CustomColorTheme) async throws {
        self.didSavedThemes.append(theme)
        self.themes[theme.uuid] = theme
    }

    func removeTheme(_ uuid: String) async throws {
        self.didRemovedThemeIds.append(uuid)
        self.themes[uuid] = nil
    }
}

private struct DummyResponse {

    private func themeJson(_ uuid: String, name: String, createdAt: Int) -> String {
        return """
        {
            "uuid": "\(uuid)",
            "name": "\(name)",
            "schema_version": 1,
            "seeds": { "background": "#F4F1EA", "accent": "#2B6CB0", "form": "grouped", "ai": "#ABCDEF" },
            "colors": { "bg0": "#F4F1EA" },
            "created_at": \(createdAt),
            "updated_at": \(createdAt + 50)
        }
        """
    }

    var responses: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .get,
                endpoint: AppSettingEndpoints.colorThemes,
                resultJsonString: .success(
                    "[\(self.themeJson("late", name: "산", createdAt: 300)), \(self.themeJson("early", name: "바다", createdAt: 100))]"
                )
            ),
            .init(
                method: .put,
                endpoint: AppSettingEndpoints.colorTheme(uuid: "early"),
                resultJsonString: .success(self.themeJson("early", name: "바다", createdAt: 100))
            ),
            .init(
                method: .delete,
                endpoint: AppSettingEndpoints.colorTheme(uuid: "early"),
                resultJsonString: .success(#"{ "status": "ok" }"#)
            )
        ]
    }

    var missingRequiredSeedResponses: [StubRemoteAPI.Response] {
        let missingAccent = """
        {
            "uuid": "no_accent",
            "name": "바다",
            "schema_version": 1,
            "seeds": { "background": "#F4F1EA", "form": "grouped" },
            "colors": {},
            "created_at": 100,
            "updated_at": 150
        }
        """
        return [
            .init(
                method: .get,
                endpoint: AppSettingEndpoints.colorThemes,
                resultJsonString: .success("[\(missingAccent)]")
            )
        ]
    }

    var failResponses: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .get,
                endpoint: AppSettingEndpoints.colorThemes,
                resultJsonString: .failure(RuntimeError("failed"))
            ),
            .init(
                method: .put,
                endpoint: AppSettingEndpoints.colorTheme(uuid: "early"),
                resultJsonString: .failure(RuntimeError("failed"))
            ),
            .init(
                method: .delete,
                endpoint: AppSettingEndpoints.colorTheme(uuid: "early"),
                resultJsonString: .failure(RuntimeError("failed"))
            )
        ]
    }
}
