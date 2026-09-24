//
//  ColorSetKeysTests.swift
//  CommonPresentationTests
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit
import Domain

@testable import CommonPresentation


struct ColorSetKeysTests {

    @Test(
        "convert maps key and system scheme to color set",
        arguments: [
            (ColorSetKeys.systemTheme, true, true),
            (ColorSetKeys.systemTheme, false, false),
            (ColorSetKeys.defaultLight, true, false),
            (ColorSetKeys.defaultLight, false, false),
            (ColorSetKeys.defaultDark, true, true),
            (ColorSetKeys.defaultDark, false, true),
            (ColorSetKeys.appTheme(.tomato), true, false),
            (ColorSetKeys.appTheme(.tomato), false, false)
        ]
    )
    func convert_mapsKeyAndSystemScheme(
        _ key: ColorSetKeys, _ isSystemDarkTheme: Bool, _ expectDarkSet: Bool
    ) {
        // given + when
        let colorSet = key.convert(isSystemDarkTheme: isSystemDarkTheme)

        // then
        #expect(colorSet.isLightTheme == (expectDarkSet == false))
    }

    @Test(
        "시스템 테마 셋은 출시된 기본 팔레트를 그대로 돌려준다",
        arguments: [
            (ColorSetKeys.systemTheme, true, true),
            (ColorSetKeys.systemTheme, false, false),
            (ColorSetKeys.defaultLight, true, false),
            (ColorSetKeys.defaultLight, false, false),
            (ColorSetKeys.defaultDark, true, true),
            (ColorSetKeys.defaultDark, false, true)
        ]
    )
    func convert_systemKeysReturnShippedDefaultPalette(
        _ key: ColorSetKeys, _ isSystemDarkTheme: Bool, _ expectDarkSet: Bool
    ) {
        // given
        let expected: any ColorSet = expectDarkSet
            ? DefaultDarkColorSet() : DefaultLightColorSet()

        // when
        let colorSet = key.convert(isSystemDarkTheme: isSystemDarkTheme)

        // then
        #expect(colorSet.bg0 == expected.bg0)
        #expect(colorSet.accent == expected.accent)
        #expect(colorSet.text0 == expected.text0)
    }

    @Test(
        "기본 제공 테마 키는 시스템 스킴과 무관하게 자기 정의를 돌려준다",
        arguments: [true, false]
    )
    func convert_appThemeReturnsItsOwnDefinition(_ isSystemDarkTheme: Bool) {
        // given + when
        let colorSet = ColorSetKeys.appTheme(.tomato)
            .convert(isSystemDarkTheme: isSystemDarkTheme)

        // then
        #expect(colorSet.accent == UIColor(rgb: 0xE54D2E))
        #expect(colorSet.bg0 == UIColor(rgb: 0xF1F0EF))
    }

    @Test("출시된 색 묶음 셋이 밝기를 제 값으로 답한다")
    func isLightTheme_answersForEveryShippedColorSet() {
        // given + when + then
        #expect(DefaultLightColorSet().isLightTheme == true)
        #expect(DefaultDarkColorSet().isLightTheme == false)
        #expect(AppThemeColorSetKey.tomato.definition.isLightTheme == true)
    }
}
