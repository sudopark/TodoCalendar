//
//  WidgetBackgroundStyleTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics
import Domain
import CommonPresentation

@testable import WidgetScenes


struct WidgetBackgroundColorSetTests {

    @Test(arguments: [true, false])
    func systemBackground_followsSystemAppearance(_ systemIsLight: Bool) {
        // given
        let background = WidgetAppearanceSettings.Background.system

        // when
        let colorSet = background.colorSet(systemIsLight)

        // then
        #expect((colorSet is DefaultLightColorSet) == systemIsLight)
    }

    @Test(arguments: [true, false])
    func customLightBackground_usesLightColorSetRegardlessOfSystem(_ systemIsLight: Bool) {
        // given
        let background = WidgetAppearanceSettings.Background.custom(hex: "#FFFFFF")

        // when
        let colorSet = background.colorSet(systemIsLight)

        // then
        #expect(colorSet is DefaultLightColorSet)
    }

    @Test(arguments: [true, false])
    func customDarkBackground_usesDarkColorSetRegardlessOfSystem(_ systemIsLight: Bool) {
        // given
        let background = WidgetAppearanceSettings.Background.custom(hex: "#000000")

        // when
        let colorSet = background.colorSet(systemIsLight)

        // then
        #expect(colorSet is DefaultDarkColorSet)
    }

    @Test(arguments: [true, false])
    func customBackgroundWithUnparsableHex_fallsBackToSystemAppearance(_ systemIsLight: Bool) {
        // given
        let background = WidgetAppearanceSettings.Background.custom(hex: "not-a-hex")

        // when
        let colorSet = background.colorSet(systemIsLight)

        // then
        #expect((colorSet is DefaultLightColorSet) == systemIsLight)
    }
}


// MARK: - 스타일이 건 배경색 얹기

struct WidgetAppearanceSettingsOverridingBackgroundTests {

    private var globalCustom: WidgetAppearanceSettings {
        return WidgetAppearanceSettings() |> \.background .~ .custom(hex: "#ffffff")
    }

    @Test("스타일이 색을 걸었으면 그 색으로 갈아끼운다")
    func overridingBackground_whenStyleHasOne_usesIt() {
        // given
        let setting = self.globalCustom

        // when
        let overridden = setting.overridingBackground(.custom(hex: "#101820"))

        // then
        #expect(overridden.background == .custom(hex: "#101820"))
    }

    @Test("스타일이 색을 안 걸었으면 전역 배경색이 그대로다")
    func overridingBackground_whenStyleHasNone_keepsGlobal() {
        // given
        let setting = self.globalCustom

        // when
        let overridden = setting.overridingBackground(nil)

        // then
        #expect(overridden.background == .custom(hex: "#ffffff"))
    }

    @Test("스타일이 시스템 배경을 걸면 전역이 사용자 색이어도 시스템이 이긴다")
    func overridingBackground_whenStyleIsSystem_beatsCustomGlobal() {
        // given
        let setting = self.globalCustom

        // when
        let overridden = setting.overridingBackground(.system)

        // then
        #expect(overridden.background == .system)
    }
}
