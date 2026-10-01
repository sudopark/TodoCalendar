//
//  ColorMathTests.swift
//  CommonPresentationTests
//
//  Created by sudo.park on 10/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit

@testable import CommonPresentation


private typealias OKLCH = CustomColorThemeBuilder.OKLCH


struct ColorMathTests {

    private let colorMath: CustomColorThemeBuilder.ColorMath = CustomColorThemeBuilder.ColorMath()

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

    @Test("대비비가 스펙 대비 표의 값과 같다")
    func contrastRatio_matchesSpecTable() {
        // given + when + then
        // 루비 eventText/todayBackground 4.52
        let ruby = self.colorMath.contrastRatio(UIColor(rgb: 0xB72247), UIColor(rgb: 0xFFCED6))
        #expect(abs(ruby - 4.5156) < 0.001)
        // 토마토 태그/bg0 3.20
        let tag = self.colorMath.contrastRatio(UIColor(rgb: 0x088CDA), UIColor(rgb: 0xF1F0EF))
        #expect(abs(tag - 3.1955) < 0.001)
        // 공휴일 태그 #D6236A / 토마토 bg0
        let holiday = self.colorMath.contrastRatio(UIColor(rgb: 0xD6236A), UIColor(rgb: 0xF1F0EF))
        #expect(abs(holiday - 4.2831) < 0.001)
    }

    @Test("대비비는 인자 순서와 무관하고 흰색 대 검정은 21이다")
    func contrastRatio_isSymmetric() {
        let black = UIColor(rgb: 0x000000)
        let white = UIColor(rgb: 0xFFFFFF)
        #expect(abs(self.colorMath.contrastRatio(white, black) - 21) < 0.0001)
        #expect(abs(self.colorMath.contrastRatio(black, white) - 21) < 0.0001)
    }

    @Test("OKLCH 변환 후 되돌려도 1/255 안에서 같다")
    func oklch_roundTrip_withinTolerance() {
        [0xE54D2E, 0x088CDA, 0x7C5CFA, 0xD6236A, 0x21201C, 0xFFFFFF, 0x000000].forEach {
            let color = UIColor(rgb: $0)
            expectSameRGB(OKLCH(color).uiColor, color)
        }
    }

    @Test("OKLCH 값이 Python 참조와 같다")
    func oklch_matchesPythonReference() {
        let oklch = OKLCH(UIColor(rgb: 0xE54D2E))
        #expect(abs(oklch.lightness - 0.62708) < 0.0005)
        #expect(abs(oklch.chroma - 0.19358) < 0.0005)
        #expect(abs(oklch.hue - 33.339) < 0.05)
    }

    @Test("무채색의 hue 는 0 이다")
    func oklch_achromatic_hueIsZero() {
        #expect(OKLCH(UIColor(rgb: 0x808080)).hue == 0)
        #expect(OKLCH(UIColor(rgb: 0xFFFFFF)).hue == 0)
    }

    @Test("강조색에 AI 보라를 40% 섞은 값이 Python 참조와 같다")
    func mixed_matchesPythonAccentAI() {
        let mixed = self.colorMath.mixed(UIColor(rgb: 0xE54D2E), with: UIColor(rgb: 0x7C5CFA), ratio: 0.4)
        expectSameRGB(mixed, UIColor(rgb: 0xBB5380))
    }

    @Test("gamut 밖 OKLCH 는 채도를 줄여 gamut 안으로 들어온다")
    func oklch_outOfGamut_reducesChroma() {
        let color = OKLCH(lightness: 0.7, chroma: 0.3, hue: 200).uiColor
        expectSameRGB(color, UIColor(rgb: 0x22B3BA))
        #expect(OKLCH(color).chroma < 0.2)
    }

    @Test("채도가 바닥 이하이면 gamut 밖이어도 줄이지 않고 클램프한다")
    func oklch_outOfGamut_lowChromaClamps() {
        let color = OKLCH(lightness: 1.2, chroma: 0.005, hue: 200).uiColor
        expectSameRGB(color, UIColor(rgb: 0xFFFFFF))
    }

    @Test("rotated 는 hue 를 0~360 안으로 감는다")
    func rotated_wrapsHue() {
        let base = OKLCH(lightness: 0.5, chroma: 0.1, hue: 350)
        #expect(base.rotated(by: 40).hue == 30)
        #expect(OKLCH(lightness: 0.5, chroma: 0.1, hue: 10).rotated(by: -40).hue == 330)
    }

    @Test("with(lightness:) 는 명도만 바꾼다")
    func with_changesOnlyLightness() {
        let changed = OKLCH(lightness: 0.5, chroma: 0.1, hue: 120).with(lightness: 0.8)
        #expect(changed == OKLCH(lightness: 0.8, chroma: 0.1, hue: 120))
    }

    @Test("eightBit 은 채널을 0~1 로 자른 뒤 가장 가까운 8비트 값으로 반올림한다")
    func eightBit_roundsToNearestByte() {
        let rounded = self.colorMath.eightBit(UIColor(red: 0.5, green: 0.2, blue: 0.003, alpha: 1))
        expectSameRGB(rounded, UIColor(rgb: 0x803301))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        rounded.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(red * 255 == 128)
        #expect(green * 255 == 51)
        #expect(blue * 255 == 1)
    }
}
