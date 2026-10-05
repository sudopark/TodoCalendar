//
//  CustomColorThemeDefinitionTests.swift
//  CommonPresentationTests
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit
import Domain

@testable import CommonPresentation


struct CustomColorThemeDefinitionTests {

    private func makeTheme(
        background: String = "#F1F0EF",
        accent: String = "#E54D2E",
        form: CustomColorThemeForm = .grouped,
        name: String = "내 테마",
        optionalSeeds: (inout CustomColorThemeSeeds) -> Void = { _ in }
    ) -> CustomColorTheme {
        var seeds = CustomColorThemeSeeds(background: background, accent: accent, form: form)
        optionalSeeds(&seeds)
        return CustomColorTheme(
            uuid: "id", name: name, schemaVersion: 1, seeds: seeds, colors: [:],
            createdAt: 0, updatedAt: 0
        )
    }

    @Test("정의 이름은 테마 이름을 커스텀 이름으로 쓴다")
    func definition_usesThemeNameAsCustomName() {
        // given
        let theme = self.makeTheme(name: "내 테마")

        // when
        let definition = theme.definition()

        // then
        #expect(definition?.name == .custom("내 테마"))
    }

    @Test("시드 hex 를 엔진에 넘겨 파생한 정의를 돌려준다")
    func definition_buildsFromSeedHex() {
        // given
        let theme = self.makeTheme(background: "#18181A", accent: "#E54D2E", form: .filled) {
            $0.text = "#F8F8F9"
        }
        let expected = CustomColorThemeBuilder().build(
            name: "내 테마",
            seeds: .init(
                background: UIColor(rgb: 0x18181A),
                accent: UIColor(rgb: 0xE54D2E),
                text: UIColor(rgb: 0xF8F8F9),
                form: .filled
            )
        )

        // when
        let definition = theme.definition()

        // then
        #expect(definition?.bg0 == expected.bg0)
        #expect(definition?.accent == expected.accent)
        #expect(definition?.text0 == expected.text0)
        #expect(definition?.isLightTheme == false)
    }

    @Test("선택 시드 다섯과 형을 모두 엔진 입력의 제 자리에 넣는다")
    func definition_mapsEveryOptionalSeedAndForm() {
        // given
        let theme = self.makeTheme(background: "#F1F0EF", accent: "#E54D2E", form: .outlined) {
            $0.text = "#1A2B3C"
            $0.surface = "#EDE7F6"
            $0.today = "#C8E6C9"
            $0.selectedDay = "#7B1FA2"
            $0.holidayOrWeekEnd = "#D81B60"
            $0.ai = "#00897B"
        }
        let seeds = { (form: CustomColorThemeBuilder.Seeds.Form) in
            CustomColorThemeBuilder.Seeds(
                background: UIColor(rgb: 0xF1F0EF),
                accent: UIColor(rgb: 0xE54D2E),
                text: UIColor(rgb: 0x1A2B3C),
                surface: UIColor(rgb: 0xEDE7F6),
                today: UIColor(rgb: 0xC8E6C9),
                selectedDay: UIColor(rgb: 0x7B1FA2),
                holidayOrWeekEnd: UIColor(rgb: 0xD81B60),
                ai: UIColor(rgb: 0x00897B),
                form: form
            )
        }
        let expected = CustomColorThemeBuilder().build(name: "내 테마", seeds: seeds(.outlined))
        let withOtherForm = CustomColorThemeBuilder().build(name: "내 테마", seeds: seeds(.filled))

        // when
        let definition = theme.definition()

        // then
        #expect(definition?.exportedColors == expected.exportedColors)
        #expect(expected.exportedColors != withOtherForm.exportedColors)
    }

    @Test("필수 시드가 hex 로 안 읽히면 nil 이다", arguments: [
        ("zzz", "#E54D2E"), ("#F1F0EF", "red"), ("", "")
    ])
    func definition_whenRequiredSeedInvalid_isNil(_ background: String, _ accent: String) {
        // given
        let theme = self.makeTheme(background: background, accent: accent)

        // when + then
        #expect(theme.definition() == nil)
    }

    @Test("선택 시드가 hex 로 안 읽히면 없는 것으로 친다")
    func definition_whenOptionalSeedInvalid_ignoresIt() {
        // given
        let withInvalid = self.makeTheme { $0.text = "not-hex" }
        let expected = CustomColorThemeBuilder().build(
            name: "내 테마",
            seeds: .init(
                background: UIColor(rgb: 0xF1F0EF), accent: UIColor(rgb: 0xE54D2E), form: .grouped
            )
        )

        // when
        let definition = withInvalid.definition()

        // then
        #expect(definition?.exportedColors == expected.exportedColors)
    }

    @Test("펼친 색은 필수 정의 필드마다 #RRGGBB 를 든다")
    func exportedColors_hasHexForEveryRequiredField() {
        // given
        let definition = ColorThemeDefinition(
            name: .custom("t"),
            bg0: UIColor(rgb: 0x000001), bg1: UIColor(rgb: 0x000002),
            todayBackground: UIColor(rgb: 0x000003), line: UIColor(rgb: 0x000004),
            text0: UIColor(rgb: 0x000005), text1: UIColor(rgb: 0x000006),
            accent: UIColor(rgb: 0x000007), selectedDayBackground: UIColor(rgb: 0x000008),
            selectedDayText: UIColor(rgb: 0x000009), holidayOrWeekEndWithAccent: UIColor(rgb: 0x00000A),
            bg2: UIColor(rgb: 0x00000B), text2: UIColor(rgb: 0x00000C),
            placeHolder: UIColor(rgb: 0x00000D), secondaryBtnBackground: UIColor(rgb: 0x00000E),
            accentAI: UIColor(rgb: 0x00000F),
            aiListeningBackgroundBase: [
                UIColor(rgb: 0xAA0001), UIColor(rgb: 0xAA0002), UIColor(rgb: 0xAA0003)
            ]
        )

        // when
        let colors = definition.exportedColors

        // then
        #expect(colors == [
            "bg0": "#000001", "bg1": "#000002", "todayBackground": "#000003",
            "line": "#000004", "text0": "#000005", "text1": "#000006",
            "accent": "#000007", "selectedDayBackground": "#000008",
            "selectedDayText": "#000009", "holidayOrWeekEndWithAccent": "#00000A",
            "bg2": "#00000B", "text2": "#00000C", "placeHolder": "#00000D",
            "secondaryBtnBackground": "#00000E", "accentAI": "#00000F",
            "aiListeningBackgroundBase0": "#AA0001",
            "aiListeningBackgroundBase1": "#AA0002",
            "aiListeningBackgroundBase2": "#AA0003"
        ])
    }

    @Test("펼친 색은 override 가 있을 때만 그 키를 든다")
    func exportedColors_includesOverrideOnlyWhenPresent() {
        // given
        let base = ColorThemeDefinition(
            name: .custom("t"),
            bg0: .white, bg1: .white, todayBackground: .white, line: .white,
            text0: .white, text1: .white, accent: .white, selectedDayBackground: .white,
            selectedDayText: .white, holidayOrWeekEndWithAccent: .white, bg2: .white,
            text2: .white, placeHolder: .white, secondaryBtnBackground: .white,
            accentAI: .white, aiListeningBackgroundBase: [.white, .white, .white]
        )
        let withOverride = ColorThemeDefinition(
            name: .custom("t"),
            bg0: .white, bg1: .white, todayBackground: .white, line: .white,
            text0: .white, text1: .white, accent: .white, selectedDayBackground: .white,
            selectedDayText: .white, holidayOrWeekEndWithAccent: .white, bg2: .white,
            text2: .white, placeHolder: .white, secondaryBtnBackground: .white,
            accentAI: .white, aiListeningBackgroundBase: [.white, .white, .white],
            eventTextOverride: UIColor(rgb: 0x112233),
            primaryBtnTextOverride: UIColor(rgb: 0x445566),
            weekDayTextOverride: UIColor(rgb: 0x010101),
            holidayTextOverride: UIColor(rgb: 0x020202),
            weekEndTextOverride: UIColor(rgb: 0x030303),
            eventTextSelectedOverride: UIColor(rgb: 0x040404),
            aiUserBubbleBackgroundOverride: UIColor(rgb: 0x050505),
            negativeBtnBackgroundOverride: UIColor(rgb: 0x060606)
        )

        // when
        let baseKeys = Set(base.exportedColors.keys)
        let overrideColors = withOverride.exportedColors
        let addedKeys = Set(overrideColors.keys).subtracting(baseKeys)

        // then
        #expect(addedKeys == [
            "eventTextOverride", "primaryBtnTextOverride", "weekDayTextOverride",
            "holidayTextOverride", "weekEndTextOverride", "eventTextSelectedOverride",
            "aiUserBubbleBackgroundOverride", "negativeBtnBackgroundOverride"
        ])
        #expect(overrideColors["eventTextOverride"] == "#112233")
        #expect(overrideColors["primaryBtnTextOverride"] == "#445566")
    }

    @Test("엔진이 만든 정의도 모든 값이 #RRGGBB 형식이다")
    func exportedColors_ofBuiltDefinition_areHexForm() {
        // given
        let definition = self.makeTheme().definition()

        // when
        let colors = definition?.exportedColors ?? [:]

        // then
        #expect(colors.isEmpty == false)
        colors.values.forEach {
            #expect($0.range(of: "^#[0-9A-F]{6}$", options: .regularExpression) != nil, "\($0)")
        }
    }

    @Test("UIColor 를 대문자 #RRGGBB 로 바꾸고 반올림한다")
    func rgbHexString_formatsAsUppercaseRRGGBB() {
        // given + when + then
        #expect(UIColor(rgb: 0x18181A).rgbHexString == "#18181A")
        #expect(UIColor(rgb: 0xE54D2E).rgbHexString == "#E54D2E")
        #expect(UIColor.white.rgbHexString == "#FFFFFF")
        #expect(UIColor(red: 0.5, green: 0.0, blue: 1.0, alpha: 1.0).rgbHexString == "#8000FF")
    }
}
