//
//  WidgetBackgroundStyleTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
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
        #expect(colorSet.isLightTheme == systemIsLight)
    }

    @Test(arguments: [true, false])
    func customLightBackground_usesLightColorSetRegardlessOfSystem(_ systemIsLight: Bool) {
        // given
        let background = WidgetAppearanceSettings.Background.custom(hex: "#FFFFFF")

        // when
        let colorSet = background.colorSet(systemIsLight)

        // then
        #expect(colorSet.isLightTheme == true)
    }

    @Test(arguments: [true, false])
    func customDarkBackground_usesDarkColorSetRegardlessOfSystem(_ systemIsLight: Bool) {
        // given
        let background = WidgetAppearanceSettings.Background.custom(hex: "#000000")

        // when
        let colorSet = background.colorSet(systemIsLight)

        // then
        #expect(colorSet.isLightTheme == false)
    }

    @Test(arguments: [true, false])
    func customBackgroundWithUnparsableHex_fallsBackToSystemAppearance(_ systemIsLight: Bool) {
        // given
        let background = WidgetAppearanceSettings.Background.custom(hex: "not-a-hex")

        // when
        let colorSet = background.colorSet(systemIsLight)

        // then
        #expect(colorSet.isLightTheme == systemIsLight)
    }
}


// MARK: - 사진 위 대비 보정

struct WidgetLookColorSetTests {

    private func makeLook(
        background: WidgetAppearanceSettings.Background,
        photo: WidgetStylePhoto?
    ) -> WidgetLook {
        return WidgetLook(
            globalSetting: WidgetAppearanceSettings(),
            appliedStyle: WidgetStyle(
                id: .init(variant: .ddaySmall, style: .default),
                name: nil, setting: DDayStyleSetting.initial,
                background: background, photo: photo
            )
        )
    }

    private var shippedDark: any ColorSet {
        return ColorSetKeys.defaultDark.convert(isSystemDarkTheme: true)
    }

    private var somePhoto: WidgetStylePhoto {
        return .init(
            id: "p1",
            original: URL(filePath: "/tmp/p1.original"),
            rendering: URL(filePath: "/tmp/p1.render.jpg")
        )
    }

    @Test("사진이 깔리면 배경색·시스템 테마와 무관하게 다크로 고정한다", arguments: [true, false])
    func colorSet_whenPhotoExists_isDarkRegardlessOfSystemTheme(_ systemIsLight: Bool) {
        // given
        let look = self.makeLook(
            background: .custom(hex: "#FFFFFF"), photo: self.somePhoto
        )

        // when
        let colorSet = look.colorSet(systemIsLight)

        // then
        #expect(colorSet.isLightTheme == false)
    }

    @Test("사진이 없으면 배경색 판정을 그대로 탄다", arguments: [true, false])
    func colorSet_whenNoPhoto_followsBackground(_ systemIsLight: Bool) {
        // given
        let light = self.makeLook(background: .custom(hex: "#FFFFFF"), photo: nil)
        let dark = self.makeLook(background: .custom(hex: "#000000"), photo: nil)

        // when + then
        #expect(light.colorSet(systemIsLight).isLightTheme == true)
        #expect(dark.colorSet(systemIsLight).isLightTheme == false)
    }

    @Test("사진 위에선 보조 글자를 한 단계 올린다", arguments: [true, false])
    func subTextColor_whenPhotoExists_isOneStepBrighterThanText2(_ systemIsLight: Bool) {
        // given
        let look = self.makeLook(
            background: .custom(hex: "#FFFFFF"), photo: self.somePhoto
        )

        // when
        let color = look.subTextColor(systemIsLight)

        // then
        #expect(color == self.shippedDark.text1)
        #expect(color != self.shippedDark.text2)
    }

    @Test("사진이 없으면 보조 글자는 text2 그대로다", arguments: [true, false])
    func subTextColor_whenNoPhoto_isText2(_ systemIsLight: Bool) {
        // given
        let look = self.makeLook(background: .custom(hex: "#000000"), photo: nil)

        // when
        let color = look.subTextColor(systemIsLight)

        // then
        #expect(color == self.shippedDark.text2)
        #expect(color != self.shippedDark.text1)
    }
}
