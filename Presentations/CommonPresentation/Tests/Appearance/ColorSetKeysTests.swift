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
        let expected = expectDarkSet ? self.shippedDarkPalette : self.shippedLightPalette

        // when
        let colorSet = key.convert(isSystemDarkTheme: isSystemDarkTheme)

        // then
        let actual = self.palette(of: colorSet)
        #expect(actual.keys.sorted() == expected.keys.sorted())
        expected.forEach { token, color in
            #expect(actual[token] == color, "\(token)")
        }
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
        #expect(ColorSetKeys.defaultLight.convert(isSystemDarkTheme: true).isLightTheme == true)
        #expect(ColorSetKeys.defaultDark.convert(isSystemDarkTheme: false).isLightTheme == false)
        #expect(AppThemeColorSetKey.tomato.definition.isLightTheme == true)
    }
}


// MARK: - shipped palette

extension ColorSetKeysTests {

    private func palette(of colorSet: any ColorSet) -> [String: UIColor] {
        let listening = colorSet.aiListeningBackground
        return [
            "weekDayText": colorSet.weekDayText,
            "weekEndText": colorSet.weekEndText,
            "dayBackground": colorSet.dayBackground,
            "selectedDayBackground": colorSet.selectedDayBackground,
            "selectedDayText": colorSet.selectedDayText,
            "holidayText": colorSet.holidayText,
            "todayBackground": colorSet.todayBackground,
            "eventText": colorSet.eventText,
            "eventTextSelected": colorSet.eventTextSelected,
            "holidayOrWeekEndWithAccent": colorSet.holidayOrWeekEndWithAccent,
            "uncompletedTodo": colorSet.uncompletedTodo,
            "text0": colorSet.text0,
            "text1": colorSet.text1,
            "text2": colorSet.text2,
            "placeHolder": colorSet.placeHolder,
            "text0_inverted": colorSet.text0_inverted,
            "primaryBtnBackground": colorSet.primaryBtnBackground,
            "primaryBtnText": colorSet.primaryBtnText,
            "secondaryBtnBackground": colorSet.secondaryBtnBackground,
            "secondaryBtnText": colorSet.secondaryBtnText,
            "negativeBtnBackground": colorSet.negativeBtnBackground,
            "negativeBtnText": colorSet.negativeBtnText,
            "accent": colorSet.accent,
            "accentInfo": colorSet.accentInfo,
            "accentWarn": colorSet.accentWarn,
            "accentAI": colorSet.accentAI,
            "aiListeningBackground[0]": listening[0],
            "aiListeningBackground[1]": listening[1],
            "aiListeningBackground[2]": listening[2],
            "aiUserBubbleBackground": colorSet.aiUserBubbleBackground,
            "aiUserBubbleText": colorSet.aiUserBubbleText,
            "line": colorSet.line,
            "bg0": colorSet.bg0,
            "bg1": colorSet.bg1,
            "bg2": colorSet.bg2
        ]
    }

    private var shippedLightPalette: [String: UIColor] {
        return [
            "weekDayText": UIColor(rgb: 0x323232),
            "weekEndText": UIColor(rgb: 0x646464),
            "dayBackground": .white,
            "selectedDayBackground": UIColor(rgb: 0x303646),
            "selectedDayText": .white,
            "holidayText": UIColor(rgb: 0x233238),
            "todayBackground": UIColor(rgb: 0xf4f4f4),
            "eventText": UIColor(rgb: 0x45454a),
            "eventTextSelected": .white,
            "holidayOrWeekEndWithAccent": .red,
            "uncompletedTodo": UIColor(rgb: 0xea4444),
            "text0": UIColor(rgb: 0x323232),
            "text1": UIColor(rgb: 0x646464),
            "text2": UIColor(rgb: 0x969696),
            "placeHolder": UIColor(rgb: 0xccd0dc),
            "text0_inverted": .white,
            "primaryBtnBackground": .systemBlue,
            "primaryBtnText": UIColor(rgb: 0xffffff),
            "secondaryBtnBackground": .systemGray5,
            "secondaryBtnText": UIColor(rgb: 0x323232),
            "negativeBtnBackground": .systemRed,
            "negativeBtnText": UIColor(rgb: 0xffffff),
            "accent": .systemBlue,
            "accentInfo": UIColor(rgb: 0xff7417),
            "accentWarn": UIColor(rgb: 0xea4444),
            "accentAI": UIColor(rgb: 0x6272a4),
            "aiListeningBackground[0]": UIColor(rgb: 0xbd93f9).withAlphaComponent(0.20),
            "aiListeningBackground[1]": UIColor(rgb: 0xff79c6).withAlphaComponent(0.13),
            "aiListeningBackground[2]": UIColor(rgb: 0x8be9fd).withAlphaComponent(0.20),
            "aiUserBubbleBackground": UIColor(rgb: 0x44475a),
            "aiUserBubbleText": .white,
            "line": UIColor.black.withAlphaComponent(0.2),
            "bg0": .white,
            "bg1": UIColor(rgb: 0xf3f4f7),
            "bg2": UIColor(rgb: 0xf4f4f4)
        ]
    }

    private var shippedDarkPalette: [String: UIColor] {
        return [
            "weekDayText": UIColor(rgb: 0xf3f4f7),
            "weekEndText": UIColor(rgb: 0xe2e4eb),
            "dayBackground": UIColor(rgb: 0x18181a),
            "selectedDayBackground": UIColor(rgb: 0xccd0dc),
            "selectedDayText": UIColor(rgb: 0x1a153d),
            "holidayText": UIColor(rgb: 0xf4f2f8),
            "todayBackground": UIColor(rgb: 0x45454a),
            "eventText": UIColor(rgb: 0xe2e4eb),
            "eventTextSelected": UIColor(rgb: 0x151131),
            "holidayOrWeekEndWithAccent": .red,
            "uncompletedTodo": UIColor(rgb: 0xea4444),
            "text0": UIColor(rgb: 0xf8f8f9),
            "text1": UIColor(rgb: 0xf1f1f1),
            "text2": UIColor(rgb: 0xe5e5e4),
            "placeHolder": UIColor(rgb: 0xa0a0a7),
            "text0_inverted": UIColor(rgb: 0x393c3c),
            "primaryBtnBackground": .systemBlue,
            "primaryBtnText": UIColor(rgb: 0xffffff),
            "secondaryBtnBackground": UIColor(rgb: 0x71717a),
            "secondaryBtnText": UIColor(rgb: 0xf8f8f9),
            "negativeBtnBackground": .systemRed,
            "negativeBtnText": UIColor(rgb: 0xffffff),
            "accent": .systemBlue,
            "accentInfo": UIColor(rgb: 0xff7417),
            "accentWarn": UIColor(rgb: 0xea4444),
            "accentAI": UIColor(rgb: 0x6272a4),
            "aiListeningBackground[0]": UIColor(rgb: 0xbd93f9).withAlphaComponent(0.28),
            "aiListeningBackground[1]": UIColor(rgb: 0xff79c6).withAlphaComponent(0.18),
            "aiListeningBackground[2]": UIColor(rgb: 0x8be9fd).withAlphaComponent(0.26),
            "aiUserBubbleBackground": UIColor(rgb: 0xccd0dc),
            "aiUserBubbleText": UIColor(rgb: 0x1a153d),
            "line": UIColor.white.withAlphaComponent(0.2),
            "bg0": UIColor(rgb: 0x18181a),
            "bg1": UIColor(rgb: 0x45454a),
            "bg2": UIColor(rgb: 0x393c3c)
        ]
    }
}
