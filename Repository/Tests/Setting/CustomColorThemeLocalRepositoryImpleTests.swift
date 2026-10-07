//
//  CustomColorThemeLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain
import SQLiteService

@testable import Repository


struct CustomColorThemeLocalRepositoryImpleTests {

    private func makeTheme(
        _ uuid: String,
        name: String = "theme",
        createdAt: TimeInterval = 100,
        seeds: CustomColorThemeSeeds? = nil
    ) -> CustomColorTheme {
        let fullSeeds = CustomColorThemeSeeds(background: "#FFFFFF", accent: "#112233", form: .grouped)
            |> \.text .~ "#000000"
            |> \.surface .~ "#F0F0F0"
            |> \.today .~ "#AA0000"
            |> \.selectedDay .~ "#00AA00"
            |> \.holidayOrWeekEnd .~ "#0000AA"
            |> \.ai .~ "#ABCDEF"
        return CustomColorTheme(
            uuid: uuid,
            name: name,
            schemaVersion: 1,
            seeds: seeds ?? fullSeeds,
            colors: ["bg0": "#FFFFFF", "text0": "#000000"],
            createdAt: createdAt,
            updatedAt: createdAt + 1
        )
    }

    private func withRepository(
        _ body: (CustomColorThemeLocalRepositoryImple) async throws -> Void
    ) async throws {
        let path = try FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("custom_color_theme_\(UUID().uuidString).db")
            .path
        let service = SQLiteService()
        try await service.async.open(path: path)
        let storage = CustomColorThemeLocalStorageImple(sqliteService: service)
        do {
            try await body(CustomColorThemeLocalRepositoryImple(localStorage: storage))
        } catch {
            try? await service.async.close()
            try? FileManager.default.removeItem(atPath: path)
            throw error
        }
        try? await service.async.close()
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("uuid 로 읽으면 그 테마 하나만 돌려준다")
    func repository_fetchTheme_returnsMatchingTheme() async throws {
        try await self.withRepository { repository in
            // given
            let target = self.makeTheme("b", name: "target", createdAt: 200)
            try await repository.saveTheme(self.makeTheme("a"))
            try await repository.saveTheme(target)

            // when
            let theme = try await repository.fetchTheme("b")

            // then
            #expect(theme == target)
        }
    }

    @Test("없는 uuid 로 읽으면 nil 이다")
    func repository_fetchTheme_whenMissing_isNil() async throws {
        try await self.withRepository { repository in
            // given
            try await repository.saveTheme(self.makeTheme("a"))

            // when
            let theme = try await repository.fetchTheme("missing")

            // then
            #expect(theme == nil)
        }
    }

    @Test("테마를 저장하면 시드·색을 포함해 그대로 다시 읽는다")
    func repository_saveAndLoadThemes() async throws {
        try await self.withRepository { repository in
            // given
            let theme = self.makeTheme("a")

            // when
            try await repository.saveTheme(theme)
            let themes = try await repository.loadThemes()

            // then
            #expect(themes == [theme])
        }
    }

    @Test("같은 uuid 를 다시 저장하면 덮어쓴다")
    func repository_saveSameUuid_overwrites() async throws {
        try await self.withRepository { repository in
            // given
            try await repository.saveTheme(self.makeTheme("a", name: "before"))
            let renamed = self.makeTheme("a", name: "after")

            // when
            try await repository.saveTheme(renamed)
            let themes = try await repository.loadThemes()

            // then
            #expect(themes == [renamed])
        }
    }

    @Test("삭제하면 그 uuid 만 목록에서 빠진다")
    func repository_removeTheme() async throws {
        try await self.withRepository { repository in
            // given
            let kept = self.makeTheme("keep", createdAt: 1)
            try await repository.saveTheme(kept)
            try await repository.saveTheme(self.makeTheme("gone", createdAt: 2))

            // when
            try await repository.removeTheme("gone")
            let themes = try await repository.loadThemes()

            // then
            #expect(themes == [kept])
        }
    }

    @Test("목록은 생성 시각 오름차순이다")
    func repository_loadThemes_orderedByCreatedAt() async throws {
        try await self.withRepository { repository in
            // given
            try await repository.saveTheme(self.makeTheme("late", createdAt: 300))
            try await repository.saveTheme(self.makeTheme("early", createdAt: 100))
            try await repository.saveTheme(self.makeTheme("middle", createdAt: 200))

            // when
            let themes = try await repository.loadThemes()

            // then
            #expect(themes.map { $0.uuid } == ["early", "middle", "late"])
        }
    }

    @Test("선택 시드가 없는 테마도 없는 채로 왕복한다")
    func repository_seedsWithoutOptional_roundTrips() async throws {
        try await self.withRepository { repository in
            // given
            let seeds = CustomColorThemeSeeds(background: "#101010", accent: "#FF8800", form: .outlined)
            let theme = self.makeTheme("a", seeds: seeds)

            // when
            try await repository.saveTheme(theme)
            let themes = try await repository.loadThemes()

            // then
            #expect(themes.first?.seeds == seeds)
            #expect(themes.first?.seeds.text == nil)
        }
    }

    @Test("저장된 테마가 없으면 빈 목록을 준다")
    func repository_whenEmpty_loadsEmptyList() async throws {
        try await self.withRepository { repository in
            // given + when
            let themes = try await repository.loadThemes()

            // then
            #expect(themes.isEmpty)
        }
    }
}


// MARK: - 변환이 컬럼을 다 채우는지 (DB 미사용)

extension CustomColorThemeLocalRepositoryImpleTests {

    @Test("변환한 Entity 를 직렬화하면 빈 컬럼이 없다")
    func tableSerialize_fromConvertedEntity_leavesNoColumnUnmapped() throws {
        // given
        let theme = self.makeTheme("a")

        // when
        let values = try CustomColorThemeTable.serialize(entity: .init(theme))

        // then
        let unmapped = zip(CustomColorThemeTable.Columns.allCases, values)
            .filter { $0.1 == nil }
            .map { $0.0 }
        #expect(values.isEmpty == false)
        #expect(unmapped.isEmpty)
    }
}


// MARK: - 선언이 만드는 CREATE 문이 전환 전 스키마와 같은지 (DB 미사용)

extension CustomColorThemeLocalRepositoryImpleTests {

    @Test("선언이 내는 CREATE 문이 전환 전 물리 스키마와 같다")
    func tableCreateStatement_matchesPreTransitionSchema() {
        // given + when
        let statement = CustomColorThemeTable.createStatement

        // then
        #expect(statement == "CREATE TABLE IF NOT EXISTS CustomColorThemes (uuid TEXT UNIQUE NOT NULL, name TEXT NOT NULL, schema_version INTEGER NOT NULL, seeds TEXT NOT NULL, colors TEXT NOT NULL, created_at REAL NOT NULL, updated_at REAL NOT NULL,PRIMARY KEY (uuid));")
    }
}
