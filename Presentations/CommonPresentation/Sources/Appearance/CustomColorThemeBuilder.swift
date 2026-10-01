//
//  CustomColorThemeBuilder.swift
//  CommonPresentation
//
//  Created by sudo.park on 10/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Prelude
import Optics


// MARK: - CustomColorThemeBuilder

public struct CustomColorThemeBuilder: Sendable {

    public struct Seeds: Equatable, Sendable {

        public enum Form: String, CaseIterable, Sendable {
            case filled
            case grouped
            case outlined
        }

        public var background: UIColor
        public var accent: UIColor
        public var text: UIColor?
        public var surface: UIColor?
        public var today: UIColor?
        public var selectedDay: UIColor?
        public var holidayOrWeekEnd: UIColor?
        public var ai: UIColor?
        public var form: Form

        public init(
            background: UIColor,
            accent: UIColor,
            text: UIColor? = nil,
            surface: UIColor? = nil,
            today: UIColor? = nil,
            selectedDay: UIColor? = nil,
            holidayOrWeekEnd: UIColor? = nil,
            ai: UIColor? = nil,
            form: Form
        ) {
            self.background = background
            self.accent = accent
            self.text = text
            self.surface = surface
            self.today = today
            self.selectedDay = selectedDay
            self.holidayOrWeekEnd = holidayOrWeekEnd
            self.ai = ai
            self.form = form
        }
    }

    private let colorMath: ColorMath = ColorMath()
    private let adjuster: LightnessAdjuster = LightnessAdjuster()
    private let aiTokens: AITokens = AITokens()

    public init() { }

    public func build(name: String, seeds: Seeds) -> ColorThemeDefinition {
        let bg0: UIColor = self.colorMath.eightBit(self.fittedBackground(seeds.background))
        let isLight: Bool = bg0.isLight
        let palette = LadderPalette(
            ladder: self.ladder(form: seeds.form, isLight: isLight),
            background: OKLCH(bg0),
            accent: OKLCH(seeds.accent)
        )
        let derived = self.derivedTokens(seeds: seeds, bg0: bg0, isLight: isLight, palette: palette)
        let tokens = self.corrected(derived, bg0: bg0)
        let primaryBtnText: UIColor = tokens.primaryBtnTextOverride ?? Constant.white
        let accentAI: UIColor = self.aiTokens.accentAI(
            accent: tokens.accent, seed: seeds.ai, primaryBtnText: primaryBtnText
        )

        return ColorThemeDefinition(
            name: .custom(name),
            bg0: bg0,
            bg1: tokens.bg1,
            todayBackground: tokens.today,
            line: tokens.line,
            text0: tokens.text0,
            text1: tokens.text1,
            accent: tokens.accent,
            selectedDayBackground: tokens.selectedDayBackground,
            selectedDayText: self.higherContrastBase(against: tokens.selectedDayBackground),
            holidayOrWeekEndWithAccent: tokens.holidayOrWeekEnd,
            bg2: tokens.bg2,
            text2: tokens.text2,
            placeHolder: tokens.placeHolder,
            secondaryBtnBackground: tokens.secondaryBtnBackground,
            accentAI: accentAI,
            aiListeningBackgroundBase: self.aiTokens.listeningBase(of: accentAI),
            eventTextOverride: tokens.eventTextOverride,
            primaryBtnTextOverride: tokens.primaryBtnTextOverride
        )
    }
}


// MARK: - tokens

extension CustomColorThemeBuilder {

    fileprivate struct Tokens {
        var accent: UIColor
        var bg1: UIColor
        var bg2: UIColor
        var line: UIColor
        var today: UIColor
        var text0: UIColor
        var text1: UIColor
        var text2: UIColor
        var placeHolder: UIColor
        var selectedDayBackground: UIColor
        var holidayOrWeekEnd: UIColor
        var secondaryBtnBackground: UIColor
        var eventTextOverride: UIColor?
        var primaryBtnTextOverride: UIColor?
    }

    fileprivate func derivedTokens(
        seeds: Seeds, bg0: UIColor, isLight: Bool, palette: LadderPalette
    ) -> Tokens {
        let tinted: Bool = seeds.form == .filled
        let eightBit: (UIColor) -> UIColor = { self.colorMath.eightBit($0) }
        let text0: UIColor = seeds.text.map(eightBit) ?? palette.uiColor(\.text0, tinted: tinted)
        return Tokens(
            accent: eightBit(seeds.accent),
            bg1: seeds.surface.map { self.fittedSurface($0, isLight: isLight) }
                ?? palette.uiColor(\.bg1, tinted: tinted),
            bg2: palette.uiColor(\.bg2, tinted: tinted),
            line: palette.uiColor(\.line, tinted: tinted),
            today: seeds.today.map(eightBit) ?? palette.uiColor(\.today, tinted: true),
            text0: text0,
            text1: seeds.text.map { palette.textOne(derivedFrom: $0) }
                ?? palette.uiColor(\.text1, tinted: tinted),
            text2: self.floored(
                palette.oklch(\.text2, tinted: tinted), against: bg0, atLeast: Constant.text2MinContrast
            ),
            placeHolder: self.floored(
                palette.oklch(\.placeHolder, tinted: tinted), against: bg0, atLeast: Constant.placeHolderMinContrast
            ),
            selectedDayBackground: seeds.selectedDay.map(eightBit) ?? palette.uiColor(\.selectedDayBackground, tinted: true),
            holidayOrWeekEnd: seeds.holidayOrWeekEnd.map(eightBit) ?? palette.uiColor(\.holidayOrWeekEnd, tinted: true),
            secondaryBtnBackground: palette.uiColor(\.secondaryBtnBackground, tinted: tinted)
        )
    }
}


// MARK: - ladder

extension CustomColorThemeBuilder {

    fileprivate struct LadderStep {
        let lightnessOffset: CGFloat
        let chromaCap: CGFloat
    }

    fileprivate struct Ladder {
        let bg1: LadderStep
        let bg2: LadderStep
        let line: LadderStep
        let text0: LadderStep
        let text1: LadderStep
        let text2: LadderStep
        let placeHolder: LadderStep
        let today: LadderStep
        let secondaryBtnBackground: LadderStep
        let selectedDayBackground: LadderStep
        let holidayOrWeekEnd: LadderStep
    }

    fileprivate struct LadderPalette {

        let ladder: Ladder
        let background: OKLCH
        let accent: OKLCH
        let colorMath: ColorMath = ColorMath()

        func oklch(_ token: KeyPath<Ladder, LadderStep>, tinted: Bool) -> OKLCH {
            let step = ladder[keyPath: token]
            let source: OKLCH = tinted ? accent : background
            return OKLCH(
                lightness: max(0, min(1, background.lightness + step.lightnessOffset)),
                chroma: min(source.chroma, step.chromaCap),
                hue: source.hue
            )
        }

        func uiColor(_ token: KeyPath<Ladder, LadderStep>, tinted: Bool) -> UIColor {
            return self.colorMath.eightBit(self.oklch(token, tinted: tinted).uiColor)
        }

        func textOne(derivedFrom textSeed: UIColor) -> UIColor {
            let seed: OKLCH = OKLCH(textSeed)
            let gap: CGFloat = ladder.text1.lightnessOffset - ladder.text0.lightnessOffset
            return self.colorMath.eightBit(seed.with(lightness: max(0, min(1, seed.lightness + gap))).uiColor)
        }
    }
}

extension CustomColorThemeBuilder {

    // 라인업 19개(AppThemeColorSetKey+Definition)의 같은 형·계열 토큰 OKLCH L 을 bg0 L 과의 차이로 재고 중앙값을 쓴다. 채도 상한도 같은 방식이다
    fileprivate func ladder(form: Seeds.Form, isLight: Bool) -> Ladder {
        switch (form, isLight) {
        case (.grouped, true):
            return Ladder(
                bg1: .init(lightnessOffset: 0.0444, chromaCap: 0.0),
                bg2: .init(lightnessOffset: 0.0265, chromaCap: 0.0019),
                line: .init(lightnessOffset: -0.0698, chromaCap: 0.0039),
                text0: .init(lightnessOffset: -0.7137, chromaCap: 0.0086),
                text1: .init(lightnessOffset: -0.4541, chromaCap: 0.0079),
                text2: .init(lightnessOffset: -0.3177, chromaCap: 0.0062),
                placeHolder: .init(lightnessOffset: -0.1379, chromaCap: 0.0039),
                today: .init(lightnessOffset: 0.0021, chromaCap: 0.0219),
                secondaryBtnBackground: .init(lightnessOffset: -0.0698, chromaCap: 0.0039),
                selectedDayBackground: .init(lightnessOffset: -0.4029, chromaCap: 0.1783),
                holidayOrWeekEnd: .init(lightnessOffset: -0.4010, chromaCap: 0.1980)
            )
        case (.grouped, false):
            return Ladder(
                bg1: .init(lightnessOffset: 0.0744, chromaCap: 0.0035),
                bg2: .init(lightnessOffset: 0.0357, chromaCap: 0.0036),
                line: .init(lightnessOffset: 0.1702, chromaCap: 0.0064),
                text0: .init(lightnessOffset: 0.7700, chromaCap: 0.0027),
                text1: .init(lightnessOffset: 0.5894, chromaCap: 0.0099),
                text2: .init(lightnessOffset: 0.3531, chromaCap: 0.0087),
                placeHolder: .init(lightnessOffset: 0.1952, chromaCap: 0.0063),
                today: .init(lightnessOffset: 0.0775, chromaCap: 0.0548),
                secondaryBtnBackground: .init(lightnessOffset: 0.1702, chromaCap: 0.0064),
                selectedDayBackground: .init(lightnessOffset: 0.6028, chromaCap: 0.1338),
                holidayOrWeekEnd: .init(lightnessOffset: 0.6029, chromaCap: 0.1310)
            )
        case (.outlined, true):
            return Ladder(
                bg1: .init(lightnessOffset: -0.0359, chromaCap: 0.0040),
                bg2: .init(lightnessOffset: -0.0087, chromaCap: 0.0026),
                line: .init(lightnessOffset: -0.1052, chromaCap: 0.0095),
                text0: .init(lightnessOffset: -0.7476, chromaCap: 0.0097),
                text1: .init(lightnessOffset: -0.4878, chromaCap: 0.0136),
                text2: .init(lightnessOffset: -0.3541, chromaCap: 0.0110),
                placeHolder: .init(lightnessOffset: -0.1733, chromaCap: 0.0097),
                today: .init(lightnessOffset: -0.0325, chromaCap: 0.0249),
                secondaryBtnBackground: .init(lightnessOffset: -0.1052, chromaCap: 0.0095),
                selectedDayBackground: .init(lightnessOffset: -0.4399, chromaCap: 0.1733),
                holidayOrWeekEnd: .init(lightnessOffset: -0.4351, chromaCap: 0.1974)
            )
        case (.outlined, false):
            // 라인업에서 bg1 == bg0 (카드 면이 없다) 라 채도 상한을 두지 않고 배경 채도를 그대로 따른다
            return Ladder(
                bg1: .init(lightnessOffset: 0.0, chromaCap: .infinity),
                bg2: .init(lightnessOffset: 0.0357, chromaCap: 0.0021),
                line: .init(lightnessOffset: 0.1705, chromaCap: 0.0055),
                text0: .init(lightnessOffset: 0.7707, chromaCap: 0.0013),
                text1: .init(lightnessOffset: 0.5908, chromaCap: 0.0072),
                text2: .init(lightnessOffset: 0.3112, chromaCap: 0.0058),
                placeHolder: .init(lightnessOffset: 0.1782, chromaCap: 0.0055),
                today: .init(lightnessOffset: 0.0810, chromaCap: 0.0304),
                secondaryBtnBackground: .init(lightnessOffset: 0.1705, chromaCap: 0.0055),
                selectedDayBackground: .init(lightnessOffset: 0.6889, chromaCap: 0.0768),
                holidayOrWeekEnd: .init(lightnessOffset: 0.6017, chromaCap: 0.1299)
            )
        case (.filled, true):
            return Ladder(
                bg1: .init(lightnessOffset: -0.0362, chromaCap: 0.0214),
                bg2: .init(lightnessOffset: -0.0948, chromaCap: 0.0565),
                line: .init(lightnessOffset: -0.0362, chromaCap: 0.0214),
                text0: .init(lightnessOffset: -0.6542, chromaCap: 0.1092),
                text1: .init(lightnessOffset: -0.4569, chromaCap: 0.1850),
                text2: .init(lightnessOffset: -0.3394, chromaCap: 0.1389),
                placeHolder: .init(lightnessOffset: -0.1686, chromaCap: 0.0703),
                today: .init(lightnessOffset: -0.0948, chromaCap: 0.0565),
                secondaryBtnBackground: .init(lightnessOffset: -0.0948, chromaCap: 0.0565),
                selectedDayBackground: .init(lightnessOffset: -0.4569, chromaCap: 0.1850),
                holidayOrWeekEnd: .init(lightnessOffset: -0.4380, chromaCap: 0.1980)
            )
        case (.filled, false):
            return Ladder(
                bg1: .init(lightnessOffset: 0.0922, chromaCap: 0.0655),
                bg2: .init(lightnessOffset: 0.1707, chromaCap: 0.0997),
                line: .init(lightnessOffset: 0.0922, chromaCap: 0.0655),
                text0: .init(lightnessOffset: 0.7323, chromaCap: 0.0450),
                text1: .init(lightnessOffset: 0.5993, chromaCap: 0.1246),
                text2: .init(lightnessOffset: 0.3650, chromaCap: 0.0968),
                placeHolder: .init(lightnessOffset: 0.2109, chromaCap: 0.0787),
                today: .init(lightnessOffset: 0.1707, chromaCap: 0.0997),
                secondaryBtnBackground: .init(lightnessOffset: 0.1707, chromaCap: 0.0997),
                selectedDayBackground: .init(lightnessOffset: 0.5993, chromaCap: 0.1246),
                holidayOrWeekEnd: .init(lightnessOffset: 0.6029, chromaCap: 0.1289)
            )
        }
    }
}


// MARK: - background band

extension CustomColorThemeBuilder {

    fileprivate func fittedBackground(_ seed: UIColor) -> UIColor {
        let lightBand: (UIColor) -> Bool = { self.colorMath.relativeLuminance(of: $0) >= Constant.lightBandLuminance }
        let darkBand: (UIColor) -> Bool = { self.colorMath.relativeLuminance(of: $0) <= Constant.darkBandLuminance }
        let isInBand: Bool = lightBand(seed) || darkBand(seed)
        guard !isInBand else { return seed }
        let towardLight: Bool = OKLCH(seed).lightness >= Constant.bandMidLightness
        return self.adjuster.adjusted(
            seed,
            step: towardLight ? Constant.lightnessStep : -Constant.lightnessStep,
            within: 0...1,
            until: towardLight ? lightBand : darkBand
        )
    }

    fileprivate func fittedSurface(_ seed: UIColor, isLight: Bool) -> UIColor {
        return self.adjuster.adjusted(
            seed,
            step: isLight ? Constant.lightnessStep : -Constant.lightnessStep,
            within: 0...1,
            until: {
                isLight
                    ? self.colorMath.relativeLuminance(of: $0) >= Constant.lightBandLuminance
                    : self.colorMath.relativeLuminance(of: $0) <= Constant.darkBandLuminance
            }
        )
    }
}


// MARK: - contrast correction

extension CustomColorThemeBuilder {

    // 앞 단계가 고친 색을 뒤 단계가 다시 바꾸지 않도록 이 순서를 지킨다
    fileprivate func corrected(_ tokens: Tokens, bg0: UIColor) -> Tokens {
        let step: CGFloat = self.lightnessStep(awayFrom: bg0)
        let meets: (UIColor, [UIColor], CGFloat) -> Bool = { color, backgrounds, minimum in
            backgrounds.allSatisfy { self.colorMath.contrastRatio(color, $0) >= minimum }
        }

        let accent: UIColor = self.adjuster.adjusted(tokens.accent, step: step, within: 0...1) {
            meets($0, [bg0], Constant.graphicContrast)
        }
        let textBackgrounds: [UIColor] = [bg0, tokens.bg1]
        let text0: UIColor = self.adjuster.adjusted(tokens.text0, step: step, within: 0...1) {
            meets($0, textBackgrounds, Constant.textContrast)
        }
        let text1: UIColor = self.adjuster.adjusted(tokens.text1, step: step, within: 0...1) {
            meets($0, textBackgrounds, Constant.textContrast)
        }
        let holidayOrWeekEnd: UIColor = self.adjuster.adjusted(tokens.holidayOrWeekEnd, step: step, within: 0...1) {
            meets($0, [bg0], Constant.graphicContrast)
        }

        let eventTextFor: (UIColor) -> UIColor = { today in
            self.adjuster.adjusted(text1, step: step, within: 0...1) {
                meets($0, [today, bg0], Constant.textContrast)
            }
        }
        let todayLightness: CGFloat = OKLCH(tokens.today).lightness
        let bg0Lightness: CGFloat = OKLCH(bg0).lightness
        let towardBackground: CGFloat = bg0Lightness >= todayLightness
            ? Constant.lightnessStep : -Constant.lightnessStep
        let todayRange: ClosedRange<CGFloat> = min(todayLightness, bg0Lightness)...max(todayLightness, bg0Lightness)
        let today: UIColor = self.adjuster.adjusted(tokens.today, step: towardBackground, within: todayRange) {
            meets(text1, [$0], Constant.textContrast) || meets(eventTextFor($0), [$0, bg0], Constant.textContrast)
        }
        let eventTextOverride: UIColor? = meets(text1, [today], Constant.textContrast)
            ? nil : eventTextFor(today)

        let secondaryStep: CGFloat = OKLCH(tokens.secondaryBtnBackground).lightness >= OKLCH(text0).lightness
            ? Constant.lightnessStep : -Constant.lightnessStep
        let secondaryBtnBackground: UIColor = self.adjuster.adjusted(
            tokens.secondaryBtnBackground, step: secondaryStep, within: 0...1
        ) { meets($0, [text0], Constant.textContrast) }

        let primaryBtnTextOverride: UIColor? = meets(Constant.white, [accent], Constant.graphicContrast)
            ? nil : Constant.black

        return tokens
            |> \.accent .~ accent
            |> \.text0 .~ text0
            |> \.text1 .~ text1
            |> \.holidayOrWeekEnd .~ holidayOrWeekEnd
            |> \.today .~ today
            |> \.eventTextOverride .~ eventTextOverride
            |> \.secondaryBtnBackground .~ secondaryBtnBackground
            |> \.primaryBtnTextOverride .~ primaryBtnTextOverride
    }

    fileprivate func lightnessStep(awayFrom background: UIColor) -> CGFloat {
        return self.colorMath.relativeLuminance(of: background) >= Constant.darkTextLuminance
            ? -Constant.lightnessStep : Constant.lightnessStep
    }

    fileprivate func floored(_ color: OKLCH, against background: UIColor, atLeast minimum: CGFloat) -> UIColor {
        return self.adjuster.adjusted(
            color.uiColor, step: self.lightnessStep(awayFrom: background), within: 0...1
        ) { self.colorMath.contrastRatio($0, background) >= minimum }
    }

    fileprivate func higherContrastBase(against background: UIColor) -> UIColor {
        let white: UIColor = Constant.white
        let black: UIColor = Constant.black
        return self.colorMath.contrastRatio(white, background) >= self.colorMath.contrastRatio(black, background)
            ? white : black
    }
}


// MARK: - lightness adjuster

extension CustomColorThemeBuilder {

    fileprivate struct LightnessAdjuster: Sendable {

        private let colorMath: ColorMath = ColorMath()

        // 저장되는 #RRGGBB 와 같은 8비트 색으로 대비를 판정한다
        // 채도가 남은 끝점은 gamut 때문에 순백·순흑보다 대비가 낮아 끝점 대신 극단을 쓴다
        func adjusted(
            _ color: UIColor,
            step: CGFloat,
            within limit: ClosedRange<CGFloat>,
            until passes: (UIColor) -> Bool
        ) -> UIColor {
            let candidates = sequence(first: OKLCH(color)) { previous in
                let next: CGFloat = max(limit.lowerBound, min(limit.upperBound, previous.lightness + step))
                return next == previous.lightness ? nil : previous.with(lightness: next)
            }.lazy.enumerated().map {
                $0.offset == 0 ? self.colorMath.eightBit(color) : self.colorMath.eightBit($0.element.uiColor)
            }
            let achromaticExtreme: UIColor = step > 0 ? Constant.white : Constant.black
            let fullRange: Bool = limit == 0...1
            return candidates.first(where: passes)
                ?? (fullRange ? achromaticExtreme : candidates.reduce(self.colorMath.eightBit(color)) { _, candidate in candidate })
        }
    }
}


// MARK: - AI tokens

extension CustomColorThemeBuilder {

    struct AITokens: Sendable {

        private let colorMath: ColorMath = ColorMath()
        private let adjuster: LightnessAdjuster = LightnessAdjuster()

        func accentAI(accent: UIColor, seed: UIColor?, primaryBtnText: UIColor) -> UIColor {
            let start: UIColor = seed
                ?? self.colorMath.mixed(accent, with: Constant.aiPurple, ratio: Constant.aiMixRatio)
            let step: CGFloat = self.colorMath.relativeLuminance(of: primaryBtnText) > 0.5
                ? -Constant.aiLightnessStep : Constant.aiLightnessStep
            return self.adjuster.adjusted(start, step: step, within: Constant.aiLightnessRange) {
                self.colorMath.contrastRatio($0, primaryBtnText) >= Constant.graphicContrast
            }
        }

        fileprivate func listeningBase(of accentAI: UIColor) -> [UIColor] {
            let base: OKLCH = OKLCH(accentAI)
            let chroma: CGFloat = max(base.chroma, Constant.listeningChromaFloor)
            let colored = OKLCH(lightness: base.lightness, chroma: chroma, hue: base.hue)
            return [colored.rotated(by: -40).uiColor, accentAI, colored.rotated(by: 40).uiColor]
                .map { self.colorMath.eightBit($0) }
        }
    }
}


// MARK: - Constant

private enum Constant {
    static let white: UIColor = UIColor(rgb: 0xFFFFFF)
    static let black: UIColor = UIColor(rgb: 0x000000)
    static let aiPurple: UIColor = UIColor(rgb: 0x7C5CFA)

    static let text2MinContrast: CGFloat = 2.96
    static let placeHolderMinContrast: CGFloat = 1.54
    static let textContrast: CGFloat = 4.5
    static let graphicContrast: CGFloat = 3.0
    static let lightnessStep: CGFloat = 0.01

    // 기본 태그 #088CDA·#D6236A 가 배경 위에서 3:1 을 넘는 경계
    static let lightBandLuminance: CGFloat = 0.8161
    static let darkBandLuminance: CGFloat = 0.0218
    static let bandMidLightness: CGFloat = (cbrt(lightBandLuminance) + cbrt(darkBandLuminance)) / 2
    // 이 휘도 이상이면 어두운 글자, 미만이면 밝은 글자가 배경에서 멀어지는 쪽이다
    static let darkTextLuminance: CGFloat = 0.18

    static let aiMixRatio: CGFloat = 0.4
    static let aiLightnessStep: CGFloat = 0.02
    static let aiLightnessRange: ClosedRange<CGFloat> = 0.05...0.98
    static let listeningChromaFloor: CGFloat = 0.08
}
