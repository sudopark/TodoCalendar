//
//  ApplicationViewAppearanceStoreImpleTests.swift
//  TodoCalendarAppTests
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Testing
import Domain
import CommonPresentation
import UnitTestHelpKit

@testable import TodoCalendarApp


final class ApplicationViewAppearanceStoreImpleTests: AsyncEffectWaitable {

    private func makeTheme(_ id: String, background: String) -> CustomColorTheme {
        return CustomColorTheme(
            uuid: id,
            name: "t-\(id)",
            schemaVersion: 1,
            seeds: .init(background: background, accent: "#E54D2E", form: .grouped),
            colors: [:],
            createdAt: 0,
            updatedAt: 0
        )
    }

    private func expectedDefinition(background: Int) -> ColorThemeDefinition {
        return CustomColorThemeBuilder().build(
            name: "expected",
            seeds: .init(
                background: UIColor(rgb: background), accent: UIColor(rgb: 0xE54D2E), form: .grouped
            )
        )
    }

    private func expectedDarkDefinition() -> ColorThemeDefinition {
        return self.expectedDefinition(background: 0x18181A)
    }

    private func calendarSetting(
        _ key: ColorSetKeys, theme: CustomColorTheme? = nil
    ) -> CalendarAppearanceSettings {
        var calendar = CalendarAppearanceSettings(colorSetKey: key, fontSetKey: .systemDefault)
        calendar.currentCustomColorTheme = theme
        return calendar
    }

    private func setting(_ key: ColorSetKeys, theme: CustomColorTheme? = nil) -> AppearanceSettings {
        return AppearanceSettings(
            calendar: self.calendarSetting(key, theme: theme),
            defaultTagColor: .init(holiday: "", default: "")
        )
    }

    @MainActor
    private func makeStore(
        _ key: ColorSetKeys, theme: CustomColorTheme? = nil
    ) -> ApplicationViewAppearanceStoreImple {
        return ApplicationViewAppearanceStoreImple(self.setting(key, theme: theme), nil)
    }
}


extension ApplicationViewAppearanceStoreImpleTests {

    @MainActor
    @Test("키는 그대로고 테마만 바뀐 설정이 오면 새 테마로 색 세트를 다시 만든다")
    func store_notifyCalendarSetting_whenOnlyThemeChanged_reconverts() async throws {
        // given
        let store = self.makeStore(.custom("c1"), theme: self.makeTheme("c1", background: "#F1F0EF"))
        let navigationBarIdBefore = store.appearance.navigationBarId
        let updated = self.makeTheme("c1", background: "#18181A")

        // when
        store.notifyCalendarSettingChanged(self.calendarSetting(.custom("c1"), theme: updated))
        try await self.waitEffect("색 세트가 새 테마로 바뀜") {
            store.appearance.customColorTheme == updated
        }

        // then
        #expect(store.appearance.colorSet.bg0 == self.expectedDarkDefinition().bg0)
        #expect(store.appearance.navigationBarId != navigationBarIdBefore)
    }

    @MainActor
    @Test("키와 테마가 그대로인 설정이 오면 다시 그리지 않는다")
    func store_notifyCalendarSetting_whenKeyAndThemeSame_doesNotRedraw() async throws {
        // given
        let theme = self.makeTheme("c1", background: "#18181A")
        let store = self.makeStore(.custom("c1"), theme: theme)
        let navigationBarIdBefore = store.appearance.navigationBarId

        // when
        store.notifyCalendarSettingChanged(self.calendarSetting(.custom("c1"), theme: theme))
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(store.appearance.navigationBarId == navigationBarIdBefore)
        #expect(store.appearance.colorSet.bg0 == self.expectedDarkDefinition().bg0)
    }

    @MainActor
    @Test("같은 키에서 테마가 비워진 설정이 오면 시스템 테마로 돌아간다")
    func store_notifyCalendarSetting_whenThemeCleared_fallsBackToSystem() async throws {
        // given
        let store = self.makeStore(.custom("c1"), theme: self.makeTheme("c1", background: "#18181A"))

        // when
        store.notifyCalendarSettingChanged(self.calendarSetting(.custom("c1"), theme: nil))
        try await self.waitEffect("테마가 비워짐") {
            store.appearance.customColorTheme == nil
        }

        // then
        #expect(store.appearance.colorSet.bg0 == UIColor.white)
    }

    @MainActor
    @Test("전체 외형 설정 통지도 담긴 테마로 색 세트를 만든다")
    func store_notifySettingChanged_withTheme_reconverts() async throws {
        // given
        let store = self.makeStore(.systemTheme)
        let theme = self.makeTheme("c1", background: "#18181A")

        // when
        store.notifySettingChanged(self.setting(.custom("c1"), theme: theme))
        try await self.waitEffect("키와 테마가 반영됨") {
            store.appearance.colorSetKey == .custom("c1")
        }

        // then
        #expect(store.appearance.customColorTheme == theme)
        #expect(store.appearance.colorSet.bg0 == self.expectedDarkDefinition().bg0)
    }

    @MainActor
    @Test("설정이 커스텀 키와 테마를 함께 담아 바뀌면 그 테마로 색 세트를 만든다")
    func store_notifyCalendarSetting_toCustomWithTheme_usesTheme() async throws {
        // given
        let theme = self.makeTheme("c1", background: "#18181A")
        let store = self.makeStore(.systemTheme)

        // when
        store.notifyCalendarSettingChanged(self.calendarSetting(.custom("c1"), theme: theme))
        try await self.waitEffect("키가 커스텀으로 바뀜") {
            store.appearance.colorSetKey == .custom("c1")
        }

        // then
        #expect(store.appearance.colorSet.isLightTheme == false)
        #expect(store.appearance.colorSet.accent == self.expectedDarkDefinition().accent)
        #expect(store.appearance.colorSet.bg0 == self.expectedDarkDefinition().bg0)
    }

    @MainActor
    @Test("설정에 담긴 현재 테마가 첫 색 세트에 반영된다")
    func store_init_withThemeInSetting_appliesCustomColorSet() {
        // given
        let theme = self.makeTheme("c1", background: "#18181A")

        // when
        let store = self.makeStore(.custom("c1"), theme: theme)

        // then
        #expect(store.appearance.colorSet.bg0 == self.expectedDarkDefinition().bg0)
        #expect(store.appearance.customColorTheme?.uuid == "c1")
    }

    @MainActor
    @Test("계정 전환 뒤 받은 현재 테마로 갈아 끼우고, 없으면 시스템 테마로 돌아간다")
    func store_replaceCurrentTheme_afterAccountChange() {
        // given
        let store = self.makeStore(.custom("c1"), theme: self.makeTheme("c1", background: "#18181A"))
        let lightBg0 = self.expectedDefinition(background: 0xF1F0EF).bg0

        // when
        store.replaceCurrentCustomColorTheme(self.makeTheme("c1", background: "#F1F0EF"))
        let replacedBg0 = store.appearance.colorSet.bg0
        let replacedUuid = store.appearance.customColorTheme?.uuid
        store.replaceCurrentCustomColorTheme(nil)

        // then
        #expect(replacedBg0 == lightBg0)
        #expect(replacedUuid == "c1")
        #expect(store.appearance.customColorTheme == nil)
        #expect(store.appearance.colorSet.bg0 == UIColor.white)
    }
}
