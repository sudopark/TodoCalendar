//
//  CustomColorThemeBuilderTests.swift
//  CommonPresentationTests
//
//  Created by sudo.park on 10/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit

@testable import CommonPresentation


struct CustomColorThemeBuilderTests {

    private let builder: CustomColorThemeBuilder = CustomColorThemeBuilder()

    private func expectSameRGB(
        _ color: UIColor, _ expected: UIColor, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        func components(_ color: UIColor) -> [CGFloat] {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return [r, g, b, a]
        }
        zip(components(color), components(expected)).forEach {
            #expect(abs($0 - $1) <= 1.0 / 255, sourceLocation: sourceLocation)
        }
    }

    private func seeds(
        background: Int, accent: Int, form: CustomColorThemeBuilder.Seeds.Form
    ) -> CustomColorThemeBuilder.Seeds {
        return CustomColorThemeBuilder.Seeds(
            background: UIColor(rgb: background), accent: UIColor(rgb: accent), form: form
        )
    }

    @Test("묶음 밝은 계열은 명도 순서가 사다리를 따르고 값이 Python 참조와 같다")
    func derive_grouped_light_matchesLadderOrder() {
        // given
        let seeds = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        let luminances = [
            definition.bg1, definition.bg2, definition.bg0,
            definition.line, definition.text1, definition.text0
        ].map { $0.relativeLuminance }
        #expect(zip(luminances, luminances.dropFirst()).allSatisfy { $0 > $1 })
        self.expectSameRGB(definition.bg1, UIColor(rgb: 0xFFFFFF))
        self.expectSameRGB(definition.bg2, UIColor(rgb: 0xFAF9F8))
        self.expectSameRGB(definition.line, UIColor(rgb: 0xDAD9D8))
        self.expectSameRGB(definition.text0, UIColor(rgb: 0x20201F))
        self.expectSameRGB(definition.text1, UIColor(rgb: 0x646363))
        self.expectSameRGB(definition.todayBackground, UIColor(rgb: 0xFFECE8))
        self.expectSameRGB(definition.selectedDayBackground, UIColor(rgb: 0xC53C1F))
        self.expectSameRGB(definition.holidayOrWeekEndWithAccent, UIColor(rgb: 0xCB3310))
    }

    @Test("채움 형은 카드 면과 글자가 강조색 hue 를 따른다")
    func derive_filled_usesAccentHueForSurface() {
        // given
        let seeds = self.seeds(background: 0xFDFCFD, accent: 0x3E63DD, form: .filled)

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        self.expectSameRGB(definition.bg1, UIColor(rgb: 0xEAF0FF))
        self.expectSameRGB(definition.text0, UIColor(rgb: 0x1E326F))
        let accentHue: CGFloat = seeds.accent.oklch.hue
        #expect(abs(definition.bg1.oklch.hue - accentHue) < 5)
        #expect(abs(definition.line.oklch.hue - accentHue) < 5)
        #expect(abs(definition.bg2.oklch.hue - accentHue) < 5)
    }

    @Test("선 어두운 계열은 카드 면이 배경과 같고 선 색이 Python 참조와 같다")
    func derive_outlined_dark_surfaceEqualsBackground() {
        // given
        let seeds = self.seeds(background: 0x111113, accent: 0x3E63DD, form: .outlined)

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        self.expectSameRGB(definition.bg1, definition.bg0)
        self.expectSameRGB(definition.line, UIColor(rgb: 0x3A3A3C))
    }

    @Test("유저 선택 시드가 있으면 사다리 값 대신 그 색을 쓴다")
    func derive_usesUserSeedWhenProvided() {
        // given
        var seeds = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)
        seeds.text = UIColor(rgb: 0x123456)
        seeds.surface = UIColor(rgb: 0xF4F6FA)
        seeds.today = UIColor(rgb: 0xFEDCBA)
        seeds.selectedDay = UIColor(rgb: 0xEEEEEE)
        seeds.holidayOrWeekEnd = UIColor(rgb: 0x654321)

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        self.expectSameRGB(definition.text0, UIColor(rgb: 0x123456))
        self.expectSameRGB(definition.bg1, UIColor(rgb: 0xF4F6FA))
        self.expectSameRGB(definition.todayBackground, UIColor(rgb: 0xFEDCBA))
        self.expectSameRGB(definition.selectedDayBackground, UIColor(rgb: 0xEEEEEE))
        self.expectSameRGB(definition.holidayOrWeekEndWithAccent, UIColor(rgb: 0x654321))
        self.expectSameRGB(definition.selectedDayText, UIColor(rgb: 0x000000))
    }

    @Test("같은 입력은 늘 같은 정의를 낸다")
    func derive_isDeterministic() {
        // given
        let seeds = self.seeds(background: 0x181111, accent: 0xE54D2E, form: .filled)

        // when
        let first = self.builder.build(name: "t", seeds: seeds)
        let second = self.builder.build(name: "t", seeds: seeds)

        // then
        let tokens: (ColorThemeDefinition) -> [UIColor] = {
            [$0.bg0, $0.bg1, $0.bg2, $0.line, $0.text0, $0.text1, $0.text2, $0.placeHolder,
             $0.todayBackground, $0.selectedDayBackground, $0.holidayOrWeekEndWithAccent,
             $0.secondaryBtnBackground, $0.accentAI]
        }
        zip(tokens(first), tokens(second)).forEach { self.expectSameRGB($0, $1) }
    }

    @Test("text2·placeHolder 는 모든 형·계열에서 배경 대비 바닥선을 넘는다")
    func derive_textLadder_meetsContrastFloor() {
        // given
        let backgrounds: [Int] = [0xFFFFFF, 0xF1F0EF, 0xE8E0D0, 0x111113, 0x000000, 0x1A1A2E]

        // when
        let definitions = CustomColorThemeBuilder.Seeds.Form.allCases.flatMap { form in
            backgrounds.map {
                self.builder.build(
                    name: "t", seeds: self.seeds(background: $0, accent: 0x3E63DD, form: form)
                )
            }
        }

        // then
        definitions.forEach {
            #expect($0.text2.contrastRatio(with: $0.bg0) >= 2.96)
            #expect($0.placeHolder.contrastRatio(with: $0.bg0) >= 1.54)
        }
    }

    @Test("이름은 custom 이고 AI 토큰은 Python 참조와 같으며 override 는 비어 있다")
    func derive_nameAIAndOverrides() {
        // given
        let seeds = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)

        // when
        let definition = self.builder.build(name: "내 테마", seeds: seeds)

        // then
        #expect(definition.name == .custom("내 테마"))
        self.expectSameRGB(definition.accentAI, UIColor(rgb: 0xBB5380))
        #expect(definition.aiListeningBackgroundBase.count == 3)
        self.expectSameRGB(definition.aiListeningBackgroundBase[0], UIColor(rgb: 0x9C5FB5))
        self.expectSameRGB(definition.aiListeningBackgroundBase[1], UIColor(rgb: 0xBB5380))
        self.expectSameRGB(definition.aiListeningBackgroundBase[2], UIColor(rgb: 0xC1573D))
        #expect(definition.eventTextOverride == nil)
        #expect(definition.primaryBtnTextOverride == nil)
        #expect(definition.weekDayTextOverride == nil)
        #expect(definition.holidayTextOverride == nil)
        #expect(definition.weekEndTextOverride == nil)
        #expect(definition.eventTextSelectedOverride == nil)
        #expect(definition.aiUserBubbleBackgroundOverride == nil)
        #expect(definition.negativeBtnBackgroundOverride == nil)
    }

    // MARK: - FRAGO-1

    @Test("text 시드가 있으면 text1 은 시드 hue·채도에 사다리 명도 차이를 더한 값이다")
    func derive_textSeed_derivesTextOneFromSeed() {
        // given
        var seeds = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)
        seeds.text = UIColor(rgb: 0x0A1A2B)

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        self.expectSameRGB(definition.text0, UIColor(rgb: 0x0A1A2B))
        self.expectSameRGB(definition.text1, UIColor(rgb: 0x4B5E72))
        #expect(abs(definition.text1.oklch.hue - seeds.text!.oklch.hue) < 3)
    }

    @Test("채움 형의 text2·placeHolder 는 강조 hue 를 따른다")
    func derive_filled_tintsTextLadderWithAccentHue() {
        // given
        let seeds = self.seeds(background: 0xFDFCFD, accent: 0x3E63DD, form: .filled)

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        self.expectSameRGB(definition.text2, UIColor(rgb: 0x6A8BE5))
        self.expectSameRGB(definition.placeHolder, UIColor(rgb: 0xB1C5F4))
    }

    // MARK: - 사다리 값 (여섯 그룹)

    private struct LadderCase: Sendable, CustomTestStringConvertible {
        let form: CustomColorThemeBuilder.Seeds.Form
        let background: Int
        let accent: Int
        let text0: Int
        let line: Int
        let today: Int
        let text2: Int
        let placeHolder: Int
        var testDescription: String { "\(form) \(String(background, radix: 16))" }
    }

    // 기대값은 AppThemeColorSetKey+Definition 의 라인업 19개에서 같은 형·계열 토큰의 (OKLCH L − bg0 L) 중앙값을 Python 으로 따로 계산해 냈다
    private static let ladderCases: [LadderCase] = [
        LadderCase(form: .grouped, background: 0xF1F0EF, accent: 0x3E63DD, text0: 0x20201F, line: 0xDAD9D8, today: 0xEBF1FF, text2: 0x8C8B8A, placeHolder: 0xC4C3C2),
        LadderCase(form: .grouped, background: 0x121113, accent: 0x3E63DD, text0: 0xEFEEF0, line: 0x3B3A3C, today: 0x17223E, text2: 0x6D6C6E, placeHolder: 0x424043),
        LadderCase(form: .outlined, background: 0xF1F0EF, accent: 0x3E63DD, text0: 0x181817, line: 0xCFCECD, today: 0xDEE6F7, text2: 0x81807F, placeHolder: 0xB9B8B7),
        LadderCase(form: .outlined, background: 0x121113, accent: 0x3E63DD, text0: 0xEFEEEF, line: 0x3B3A3C, today: 0x1D2433, text2: 0x616063, placeHolder: 0x3D3C3E),
        LadderCase(form: .filled, background: 0xF1F0EF, accent: 0x3E63DD, text0: 0x162864, line: 0xDEE4F3, today: 0xC1D1F7, text2: 0x5F80D8, placeHolder: 0xA5B9E8),
        LadderCase(form: .filled, background: 0x121113, accent: 0x3E63DD, text0: 0xD6E2FE, line: 0x182547, today: 0x23366E, text2: 0x576EA9, placeHolder: 0x32436F),
    ]

    @Test("형·계열 여섯 그룹의 사다리 값이 Python 독립 계산과 같다", arguments: ladderCases)
    private func derive_ladderConstants_matchLineupMedians(_ ladderCase: LadderCase) {
        // given
        let seeds = self.seeds(
            background: ladderCase.background, accent: ladderCase.accent, form: ladderCase.form
        )

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        self.expectSameRGB(definition.text0, UIColor(rgb: ladderCase.text0))
        self.expectSameRGB(definition.line, UIColor(rgb: ladderCase.line))
        self.expectSameRGB(definition.todayBackground, UIColor(rgb: ladderCase.today))
        self.expectSameRGB(definition.text2, UIColor(rgb: ladderCase.text2))
        self.expectSameRGB(definition.placeHolder, UIColor(rgb: ladderCase.placeHolder))
    }

    // MARK: - 배경 구간

    @Test("구간 사이의 배경은 가까운 쪽 경계에 닿을 때까지 명도만 옮긴다")
    func background_midLightness_clampedToNearestBand() {
        // given
        let towardDark = self.seeds(background: 0x808080, accent: 0xE54D2E, form: .grouped)
        let towardLight = self.seeds(background: 0xA0A0A0, accent: 0xE54D2E, form: .grouped)
        let tinted = self.seeds(background: 0x8A7F9E, accent: 0xE54D2E, form: .grouped)

        // when
        let dark = self.builder.build(name: "t", seeds: towardDark).bg0
        let light = self.builder.build(name: "t", seeds: towardLight).bg0
        let tintedResult = self.builder.build(name: "t", seeds: tinted).bg0

        // then
        self.expectSameRGB(dark, UIColor(rgb: 0x262626))
        self.expectSameRGB(light, UIColor(rgb: 0xEAEAEA))
        self.expectSameRGB(tintedResult, UIColor(rgb: 0xF1EAFE))
        #expect(dark.relativeLuminance <= 0.0218)
        #expect(light.relativeLuminance >= 0.8161)
        #expect(abs(tintedResult.oklch.hue - tinted.background.oklch.hue) < 3)
    }

    @Test("구간 안의 배경은 그대로 둔다")
    func background_inBand_untouched() {
        [0xF1F0EF, 0xFFFFFF, 0x111113, 0x000000].forEach {
            let seeds = self.seeds(background: $0, accent: 0xE54D2E, form: .grouped)
            self.expectSameRGB(
                self.builder.build(name: "t", seeds: seeds).bg0, UIColor(rgb: $0)
            )
        }
    }

    @Test("surface 시드가 계열 구간 밖이면 구간 안으로 옮긴다")
    func background_surfaceSeed_fittedIntoFamilyBand() {
        // given
        var light = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)
        light.surface = UIColor(rgb: 0xABCDEF)
        var dark = self.seeds(background: 0x111113, accent: 0xE54D2E, form: .grouped)
        dark.surface = UIColor(rgb: 0x445566)

        // when
        let lightSurface = self.builder.build(name: "t", seeds: light).bg1
        let darkSurface = self.builder.build(name: "t", seeds: dark).bg1

        // then
        #expect(lightSurface.relativeLuminance >= 0.8161)
        #expect(darkSurface.relativeLuminance <= 0.0218)
    }

    // MARK: - 보정

    @Test("강조색이 배경과 3:1 미만이면 3:1 에 닿을 때까지 명도만 어두워진다")
    func correction_lowContrastAccent_raisesTo3() {
        // given
        let seeds = self.seeds(background: 0xF1F0EF, accent: 0xF5D90A, form: .grouped)

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        self.expectSameRGB(definition.accent, UIColor(rgb: 0x9C8A11))
        let ratio = definition.accent.contrastRatio(with: definition.bg0)
        #expect(ratio >= 3.0 && ratio < 3.1)
        #expect(abs(definition.accent.oklch.hue - seeds.accent.oklch.hue) < 3)
    }

    @Test("강조색이 이미 3:1 이상이면 그대로 둔다")
    func correction_passingAccent_untouched() {
        let seeds = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)
        self.expectSameRGB(
            self.builder.build(name: "t", seeds: seeds).accent, UIColor(rgb: 0xE54D2E)
        )
    }

    @Test("text 시드는 대비가 모자랄 때만 명도가 바뀐다")
    func correction_userTextSeed_adjustedOnlyWhenFailing() {
        // given
        var passing = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)
        passing.text = UIColor(rgb: 0x333333)
        var failing = passing
        failing.text = UIColor(rgb: 0xAAAAAA)

        // when
        let kept = self.builder.build(name: "t", seeds: passing)
        let moved = self.builder.build(name: "t", seeds: failing)

        // then
        self.expectSameRGB(kept.text0, UIColor(rgb: 0x333333))
        self.expectSameRGB(moved.text0, UIColor(rgb: 0x6B6B6B))
        [kept, moved].forEach {
            #expect($0.text0.contrastRatio(with: $0.bg0) >= 4.5)
            #expect($0.text0.contrastRatio(with: $0.bg1) >= 4.5)
            #expect($0.text1.contrastRatio(with: $0.bg0) >= 4.5)
            #expect($0.text1.contrastRatio(with: $0.bg1) >= 4.5)
        }
    }

    @Test("holiday 시드가 배경과 3:1 미만이면 한 칸 단위로 3:1 에 닿을 때까지 배경에서 멀어진다")
    func correction_holidaySeed_raisesTo3() {
        // given
        var onLight = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)
        onLight.holidayOrWeekEnd = UIColor(rgb: 0xFFD0D0)
        var onDark = self.seeds(background: 0x121113, accent: 0xE54D2E, form: .grouped)
        onDark.holidayOrWeekEnd = UIColor(rgb: 0x3A0A0A)

        // when
        let light = self.builder.build(name: "t", seeds: onLight)
        let dark = self.builder.build(name: "t", seeds: onDark)

        // then
        self.expectSameRGB(light.holidayOrWeekEndWithAccent, UIColor(rgb: 0xAA7F7F))
        self.expectSameRGB(dark.holidayOrWeekEndWithAccent, UIColor(rgb: 0x8A534E))
        [(light, 0.01), (dark, -0.01)].forEach { definition, towardBackground in
            let holiday = definition.holidayOrWeekEndWithAccent
            let previous = holiday.oklch.with(lightness: holiday.oklch.lightness + towardBackground)
            #expect(holiday.contrastRatio(with: definition.bg0) >= 3.0)
            #expect(previous.uiColor.contrastRatio(with: definition.bg0) < 3.0)
        }
    }

    @Test("text1 이 오늘 배경과 4.5:1 을 못 넘으면 eventText override 가 두 배경 모두 4.5:1 을 지킨다")
    func correction_eventTextOverride_whenTodayFails() {
        // given
        let failing = self.seeds(background: 0xF1F0EF, accent: 0x3E63DD, form: .filled)
        let passing = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)

        // when
        let overridden = self.builder.build(name: "t", seeds: failing)
        let plain = self.builder.build(name: "t", seeds: passing)

        // then
        #expect(overridden.text1.contrastRatio(with: overridden.todayBackground) < 4.5)
        let override = overridden.eventTextOverride
        #expect(override != nil)
        #expect((override?.contrastRatio(with: overridden.todayBackground) ?? 0) >= 4.5)
        #expect((override?.contrastRatio(with: overridden.bg0) ?? 0) >= 4.5)
        #expect(plain.eventTextOverride == nil)
    }

    @Test("밝은 테마에 어두운 오늘 배경이면 오늘 배경을 bg0 명도 쪽으로 당긴다")
    func correction_darkTodayOnLightTheme_pullsTodayTowardBackground() {
        // given
        var seeds = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)
        seeds.today = UIColor(rgb: 0x400000)

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        let eventText = definition.eventText
        #expect(definition.todayBackground.oklch.lightness > seeds.today!.oklch.lightness)
        #expect(definition.todayBackground.oklch.lightness <= definition.bg0.oklch.lightness)
        #expect(eventText.contrastRatio(with: definition.todayBackground) >= 4.5)
        #expect(eventText.contrastRatio(with: definition.bg0) >= 4.5)
    }

    @Test("선택일 글자는 흰색과 검정 중 선택일 배경과 대비가 큰 쪽이다")
    func correction_selectedDayText_picksHigherContrast() {
        // given
        var darkSelection = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)
        darkSelection.selectedDay = UIColor(rgb: 0x202020)
        var lightSelection = darkSelection
        lightSelection.selectedDay = UIColor(rgb: 0xEEEEEE)

        // when
        let onDark = self.builder.build(name: "t", seeds: darkSelection)
        let onLight = self.builder.build(name: "t", seeds: lightSelection)

        // then
        self.expectSameRGB(onDark.selectedDayText, UIColor(rgb: 0xFFFFFF))
        self.expectSameRGB(onLight.selectedDayText, UIColor(rgb: 0x000000))
        #expect(onDark.selectedDayText.contrastRatio(with: onDark.selectedDayBackground) >= 4.5)
        #expect(onLight.selectedDayText.contrastRatio(with: onLight.selectedDayBackground) >= 4.5)
    }

    @Test("보조 버튼 배경은 text0 와 4.5:1 에 닿을 때까지 text0 에서 멀어진다")
    func correction_secondaryBtn_reachesTextContrast() {
        // given
        var seeds = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)
        seeds.text = UIColor(rgb: 0xAAAAAA)

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        self.expectSameRGB(definition.secondaryBtnBackground, UIColor(rgb: 0xEEEDEC))
        #expect(definition.secondaryBtnBackground.contrastRatio(with: definition.text0) >= 4.5)
    }

    @Test("채도가 남은 끝점으로 못 넘으면 그 방향의 순백으로 보정한다")
    func correction_reachesAchromaticExtreme_whenTintedLimitFails() {
        // given
        var seeds = self.seeds(background: 0xFFFEF9, accent: 0xE0C6CD, form: .filled)
        let same = seeds.background
        seeds.text = same
        seeds.surface = same
        seeds.today = same
        seeds.selectedDay = same
        seeds.holidayOrWeekEnd = same

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        self.expectSameRGB(definition.secondaryBtnBackground, UIColor(rgb: 0xFFFFFF))
        #expect(definition.secondaryBtnBackground.contrastRatio(with: definition.text0) >= 4.5)
    }

    @Test("흰 글자가 강조색과 3:1 을 못 넘으면 검정을 primaryBtnText override 로 둔다")
    func correction_primaryBtnText_blackWhenWhiteFails() {
        // given
        let bright = self.seeds(background: 0x121113, accent: 0x1FD8A4, form: .grouped)
        let deep = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)

        // when
        let onBright = self.builder.build(name: "t", seeds: bright)
        let onDeep = self.builder.build(name: "t", seeds: deep)

        // then
        self.expectSameRGB(onBright.primaryBtnTextOverride ?? .clear, UIColor(rgb: 0x000000))
        #expect(onDeep.primaryBtnTextOverride == nil)
        #expect(onBright.primaryBtnText.contrastRatio(with: onBright.accent) >= 3.0)
    }

    // MARK: - AI 토큰

    @Test("accentAI 는 보정된 강조색에 보라를 40% 섞은 값이다")
    func accentAI_matchesSpecRule() {
        // given
        let tomato = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)
        let corrected = self.seeds(background: 0xF1F0EF, accent: 0xF5D90A, form: .grouped)

        // when
        let tomatoAI = self.builder.build(name: "t", seeds: tomato).accentAI
        let correctedAI = self.builder.build(name: "t", seeds: corrected).accentAI

        // then
        self.expectSameRGB(tomatoAI, UIColor(rgb: 0xBB5380))
        self.expectSameRGB(correctedAI, UIColor(rgb: 0x8F786E))
    }

    @Test("흰 글자에 섞은 색이 3:1 미만이면 명도를 0.02 씩 어둡게 옮겨 3:1 에 닿는다")
    func accentAI_shiftsLightnessUntil3_whenMixFailsAgainstWhiteText() {
        // given + when
        let result = CustomColorThemeBuilder.AITokens().accentAI(accent: UIColor(rgb: 0xE0E0E0), seed: nil, primaryBtnText: UIColor(rgb: 0xFFFFFF))

        // then
        self.expectSameRGB(result, UIColor(rgb: 0x998CC9))
        #expect(result.contrastRatio(with: UIColor(rgb: 0xFFFFFF)) >= 3.0)
        #expect(UIColor(rgb: 0x9F92CF).contrastRatio(with: UIColor(rgb: 0xFFFFFF)) < 3.0)
    }

    @Test("검정 글자에 섞은 색이 3:1 미만이면 명도를 0.02 씩 밝게 옮겨 3:1 에 닿는다")
    func accentAI_shiftsLightnessUntil3_whenMixFailsAgainstBlackText() {
        // given + when
        let result = CustomColorThemeBuilder.AITokens().accentAI(accent: UIColor(rgb: 0x202020), seed: nil, primaryBtnText: UIColor(rgb: 0x000000))

        // then
        self.expectSameRGB(result, UIColor(rgb: 0x605496))
        #expect(result.contrastRatio(with: UIColor(rgb: 0x000000)) >= 3.0)
        #expect(UIColor(rgb: 0x5A4E90).contrastRatio(with: UIColor(rgb: 0x000000)) < 3.0)
    }

    @Test("ai 시드가 흰 글자와 3:1 이상이면 섞지 않고 그 색을 accentAI 로 쓴다")
    func accentAI_usesAISeedAsIs_whenSeedPassesContrast() {
        // given
        let seeds = CustomColorThemeBuilder.Seeds(
            background: UIColor(rgb: 0xF1F0EF), accent: UIColor(rgb: 0xE54D2E),
            ai: UIColor(rgb: 0x3A5BC7), form: .grouped
        )

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        self.expectSameRGB(definition.accentAI, UIColor(rgb: 0x3A5BC7))
        self.expectSameRGB(definition.aiListeningBackgroundBase[0], UIColor(rgb: 0x017091))
        self.expectSameRGB(definition.aiListeningBackgroundBase[2], UIColor(rgb: 0x8042B1))
    }

    @Test("ai 시드가 흰 글자와 3:1 미만이면 명도만 0.02 씩 어둡게 옮겨 3:1 에 닿는다")
    func accentAI_shiftsAISeedLightnessUntil3_whenSeedFailsContrast() {
        // given
        let seeds = CustomColorThemeBuilder.Seeds(
            background: UIColor(rgb: 0xF1F0EF), accent: UIColor(rgb: 0xE54D2E),
            ai: UIColor(rgb: 0xA8D8FF), form: .grouped
        )

        // when
        let definition = self.builder.build(name: "t", seeds: seeds)

        // then
        self.expectSameRGB(definition.accentAI, UIColor(rgb: 0x6A98BD))
        #expect(definition.accentAI.contrastRatio(with: UIColor(rgb: 0xFFFFFF)) >= 3.0)
        #expect(UIColor(rgb: 0x709FC3).contrastRatio(with: UIColor(rgb: 0xFFFFFF)) < 3.0)
        #expect(abs(definition.accentAI.oklch.hue - UIColor(rgb: 0xA8D8FF).oklch.hue) < 3)
    }

    @Test("출력 색은 전부 #RRGGBB 로 정확히 표현되는 8비트 값이다")
    func derive_outputColors_areEightBit() {
        // given
        let backgrounds: [Int] = [0xF1F0EF, 0x808080, 0x121113, 0x8A7F9E]
        let accents: [Int] = [0xE54D2E, 0xF5D90A, 0x1FD8A4]

        // when
        let definitions = CustomColorThemeBuilder.Seeds.Form.allCases.flatMap { form in
            backgrounds.flatMap { background in
                accents.map {
                    self.builder.build(
                        name: "t", seeds: self.seeds(background: background, accent: $0, form: form)
                    )
                }
            }
        }

        // then
        definitions.forEach { definition in
            let colors: [UIColor] = [
                definition.bg0, definition.bg1, definition.bg2, definition.line,
                definition.text0, definition.text1, definition.text2, definition.placeHolder,
                definition.todayBackground, definition.accent, definition.selectedDayBackground,
                definition.holidayOrWeekEndWithAccent, definition.secondaryBtnBackground,
                definition.accentAI
            ] + definition.aiListeningBackgroundBase + [definition.eventTextOverride].compactMap { $0 }
            colors.forEach { color in
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                [red, green, blue].forEach {
                    #expect(abs($0 * 255 - ($0 * 255).rounded()) < 1e-6)
                }
            }
        }
    }

    @Test("listening base 는 accentAI hue 의 ±40° 이고 채도 하한이 0.08 이다")
    func listeningBase_rotatesHue40() {
        // given
        let tomato = self.seeds(background: 0xF1F0EF, accent: 0xE54D2E, form: .grouped)
        let gray = self.seeds(background: 0x121113, accent: 0x808080, form: .grouped)

        // when
        let tomatoBase = self.builder.build(name: "t", seeds: tomato).aiListeningBackgroundBase
        let grayBase = self.builder.build(name: "t", seeds: gray).aiListeningBackgroundBase

        // then
        zip(tomatoBase, [0x9C5FB5, 0xBB5380, 0xC1573D]).forEach { self.expectSameRGB($0, UIColor(rgb: $1)) }
        zip(grayBase, [0x5180B4, 0x7E72B1, 0x9E6796]).forEach { self.expectSameRGB($0, UIColor(rgb: $1)) }
        let center: CGFloat = tomatoBase[1].oklch.hue
        let hueGap: (CGFloat, CGFloat) -> CGFloat = { abs(($0 - $1 + 540).truncatingRemainder(dividingBy: 360) - 180) }
        #expect(hueGap(tomatoBase[0].oklch.hue, center - 40) < 3)
        #expect(hueGap(tomatoBase[2].oklch.hue, center + 40) < 3)
    }
}


private extension UIColor {

    var relativeLuminance: CGFloat {
        return CustomColorThemeBuilder.ColorMath().relativeLuminance(of: self)
    }

    var oklch: CustomColorThemeBuilder.OKLCH {
        return CustomColorThemeBuilder.OKLCH(self)
    }

    func contrastRatio(with other: UIColor) -> CGFloat {
        return CustomColorThemeBuilder.ColorMath().contrastRatio(self, other)
    }
}
