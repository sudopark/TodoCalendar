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

    @Test("init 에 넘긴 기기 모드를 그대로 든다", arguments: [true, false])
    func init_keepsSystemDarkTheme(_ isSystemDarkTheme: Bool) {
        // given + when
        let appearance = self.makeAppearance(.defaultLight, isSystemDarkTheme: isSystemDarkTheme)

        // then
        #expect(appearance.isSystemDarkTheme == isSystemDarkTheme)
    }
}
