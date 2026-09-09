//
//  WidgetBackgroundStyleTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
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
