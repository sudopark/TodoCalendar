//
//  ViewAppearanceTests.swift
//  CommonPresentationTests
//
//  Created by sudo.park on 9/25/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import SwiftUI
import Domain

@testable import CommonPresentation


struct ViewAppearanceTests {

    private func makeAppearance(
        _ colorSetKey: ColorSetKeys, isSystemDarkTheme: Bool
    ) -> ViewAppearance {
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: colorSetKey, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "", default: "")
        )
        return ViewAppearance(setting: setting, isSystemDarkTheme: isSystemDarkTheme)
    }

    @Test("시스템 테마는 창 스킴을 정하지 않는다", arguments: [true, false])
    func preferredColorScheme_systemTheme_isNil(_ isSystemDarkTheme: Bool) {
        // given
        let appearance = self.makeAppearance(.systemTheme, isSystemDarkTheme: isSystemDarkTheme)

        // when + then
        #expect(appearance.preferredColorScheme == nil)
    }

    @Test(
        "밝은 계열 테마는 기기가 다크여도 라이트 스킴이다",
        arguments: [ColorSetKeys.defaultLight, .appTheme(.tomato)]
    )
    func preferredColorScheme_lightFamilyTheme_isLight(_ key: ColorSetKeys) {
        // given
        let appearance = self.makeAppearance(key, isSystemDarkTheme: true)

        // when + then
        #expect(appearance.preferredColorScheme == .light)
    }

    @Test(
        "어두운 계열 테마는 기기가 라이트여도 다크 스킴이다",
        arguments: [ColorSetKeys.defaultDark, .appTheme(.midnight)]
    )
    func preferredColorScheme_darkFamilyTheme_isDark(_ key: ColorSetKeys) {
        // given
        let appearance = self.makeAppearance(key, isSystemDarkTheme: false)

        // when + then
        #expect(appearance.preferredColorScheme == .dark)
    }

    private func makeSetting(_ key: ColorSetKeys, theme: CustomColorTheme?) -> AppearanceSettings {
        var calendar = CalendarAppearanceSettings(colorSetKey: key, fontSetKey: .systemDefault)
        calendar.currentCustomColorTheme = theme
        return AppearanceSettings(calendar: calendar, defaultTagColor: .init(holiday: "", default: ""))
    }

    private func makeCustomTheme(_ id: String, background: String) -> CustomColorTheme {
        return CustomColorTheme(
            uuid: id, name: "t",
            schemaVersion: 1,
            seeds: .init(background: background, accent: "#E54D2E", form: .filled),
            colors: [:], createdAt: 0, updatedAt: 0
        )
    }

    @Test(
        "커스텀 키와 uuid 가 다른 테마거나 시드가 깨졌으면 창 스킴을 정하지 않는다",
        arguments: [("missing", true), ("broken", true), ("missing", false), ("broken", false)]
    )
    func preferredColorScheme_whenCustomThemeMissing_isNil(_ id: String, _ isSystemDarkTheme: Bool) {
        // given
        let setting = self.makeSetting(
            .custom(id), theme: self.makeCustomTheme("broken", background: "zzz")
        )
        let appearance = ViewAppearance(setting: setting, isSystemDarkTheme: isSystemDarkTheme)

        // when + then
        #expect(appearance.preferredColorScheme == nil)
        #expect(appearance.colorSet.isLightTheme == (isSystemDarkTheme == false))
    }

    @Test("키와 uuid 가 같은 커스텀 테마는 기기 모드와 무관하게 테마 밝기를 따른다", arguments: [true, false])
    func preferredColorScheme_whenCustomThemeExists_followsThemeLightness(_ isSystemDarkTheme: Bool) {
        // given
        let themes = [
            "dark": self.makeCustomTheme("dark", background: "#18181A"),
            "light": self.makeCustomTheme("light", background: "#F1F0EF")
        ]
        func appearance(_ id: String) -> ViewAppearance {
            return ViewAppearance(
                setting: self.makeSetting(.custom(id), theme: themes[id]),
                isSystemDarkTheme: isSystemDarkTheme
            )
        }

        // when + then
        #expect(appearance("dark").preferredColorScheme == .dark)
        #expect(appearance("light").preferredColorScheme == .light)
    }

    @Test("init 에 넘긴 기기 모드를 그대로 든다", arguments: [true, false])
    func init_keepsSystemDarkTheme(_ isSystemDarkTheme: Bool) {
        // given + when
        let appearance = self.makeAppearance(.defaultLight, isSystemDarkTheme: isSystemDarkTheme)

        // then
        #expect(appearance.isSystemDarkTheme == isSystemDarkTheme)
    }

    @Test("설정에 담긴 현재 커스텀 테마로 커스텀 키의 색 세트를 만든다")
    func viewAppearance_init_withCustomTheme_appliesCustomColorSet() {
        // given
        let theme = CustomColorTheme(
            uuid: "c1", name: "t",
            schemaVersion: 1,
            seeds: .init(background: "#18181A", accent: "#E54D2E", form: .filled),
            colors: [:], createdAt: 0, updatedAt: 0
        )
        let setting = self.makeSetting(.custom("c1"), theme: theme)

        // when
        let appearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)

        // then
        let expected = CustomColorThemeBuilder().build(
            name: "t",
            seeds: .init(
                background: UIColor(rgb: 0x18181A), accent: UIColor(rgb: 0xE54D2E), form: .filled
            )
        )
        #expect(appearance.colorSet.accent == expected.accent)
        #expect(appearance.colorSet.bg0 == expected.bg0)
        #expect(appearance.colorSet.isLightTheme == false)
        #expect(appearance.customColorTheme == theme)
        #expect(appearance.preferredColorScheme == .dark)
    }
}
