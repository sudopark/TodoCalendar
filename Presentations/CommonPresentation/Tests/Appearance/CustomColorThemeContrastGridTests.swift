//
//  CustomColorThemeContrastGridTests.swift
//  CommonPresentationTests
//
//  Created by sudo.park on 10/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit

@testable import CommonPresentation


struct CustomColorThemeContrastGridTests {

    private let builder: CustomColorThemeBuilder = CustomColorThemeBuilder()

    private struct ContrastCheck {
        let name: String
        let foreground: KeyPath<ColorThemeDefinition, UIColor>
        let background: KeyPath<ColorThemeDefinition, UIColor>
        let minimum: CGFloat
    }

    private struct Failure {
        let check: String
        let ratio: CGFloat
        let seedsDescription: String
    }

    private let checks: [ContrastCheck] = [
        .init(name: "text0/bg0", foreground: \.text0, background: \.bg0, minimum: 4.5),
        .init(name: "text0/bg1", foreground: \.text0, background: \.bg1, minimum: 4.5),
        .init(name: "text1/bg0", foreground: \.text1, background: \.bg0, minimum: 4.5),
        .init(name: "text1/bg1", foreground: \.text1, background: \.bg1, minimum: 4.5),
        .init(name: "weekDayText/dayBackground", foreground: \.weekDayText, background: \.dayBackground, minimum: 4.5),
        .init(name: "weekEndText/dayBackground", foreground: \.weekEndText, background: \.dayBackground, minimum: 4.5),
        .init(name: "holidayText/dayBackground", foreground: \.holidayText, background: \.dayBackground, minimum: 4.5),
        .init(name: "eventText/dayBackground", foreground: \.eventText, background: \.dayBackground, minimum: 4.5),
        .init(name: "eventText/todayBackground", foreground: \.eventText, background: \.todayBackground, minimum: 4.5),
        .init(name: "selectedDayText/selectedDayBackground", foreground: \.selectedDayText, background: \.selectedDayBackground, minimum: 4.5),
        .init(name: "aiUserBubbleText/aiUserBubbleBackground", foreground: \.aiUserBubbleText, background: \.aiUserBubbleBackground, minimum: 4.5),
        .init(name: "secondaryBtnText/secondaryBtnBackground", foreground: \.secondaryBtnText, background: \.secondaryBtnBackground, minimum: 4.5),
        .init(name: "holidayOrWeekEndWithAccent/dayBackground", foreground: \.holidayOrWeekEndWithAccent, background: \.dayBackground, minimum: 3),
        .init(name: "accent/bg0", foreground: \.accent, background: \.bg0, minimum: 3),
        .init(name: "primaryBtnText/primaryBtnBackground", foreground: \.primaryBtnText, background: \.primaryBtnBackground, minimum: 3),
        .init(name: "accentAI/primaryBtnText", foreground: \.accentAI, background: \.primaryBtnText, minimum: 3),
    ]

    private let tagColors: [(name: String, color: UIColor)] = [
        ("defaultTag", UIColor(rgb: 0x088CDA)),
        ("holidayTag", UIColor(rgb: 0xD6236A)),
    ]

    private let hues: [CGFloat] = (0..<12).map { CGFloat($0) * 30 }
    private let backgroundLightnesses: [CGFloat] = [0.05, 0.15, 0.27, 0.45, 0.70, 0.94, 0.97, 1.0]
    // 채도 0 은 hue 가 모두 같은 회색이라 hue 0 하나로만 돈다
    private let backgroundChromas: [CGFloat] = [0.0, 0.03, 0.08]
    private let accentLightnesses: [CGFloat] = [0.35, 0.60, 0.85]
    private let accentChromas: [CGFloat] = [0.03, 0.12, 0.25]


    private func failures(of seeds: CustomColorThemeBuilder.Seeds) -> [Failure] {
        let definition: ColorThemeDefinition = self.builder.build(name: "grid", seeds: seeds)
        let pairFailures: [Failure] = self.checks.compactMap { check in
            let ratio: CGFloat = definition[keyPath: check.foreground]
                .contrastRatio(with: definition[keyPath: check.background])
            return ratio < check.minimum
                ? Failure(check: check.name, ratio: ratio, seedsDescription: seeds.description)
                : nil
        }
        let tagFailures: [Failure] = self.tagColors.flatMap { tag in
            [(\ColorThemeDefinition.bg0, "bg0"), (\ColorThemeDefinition.dayBackground, "dayBackground")]
                .compactMap { (background, backgroundName) -> Failure? in
                    let ratio: CGFloat = tag.color.contrastRatio(with: definition[keyPath: background])
                    return ratio < 3
                        ? Failure(check: "\(tag.name)/\(backgroundName)", ratio: ratio, seedsDescription: seeds.description)
                        : nil
                }
        }
        return pairFailures + tagFailures
    }

    private func requiredSeedsGrid() -> [CustomColorThemeBuilder.Seeds] {
        let backgrounds: [UIColor] = self.backgroundChromas.flatMap { chroma in
            (chroma == 0 ? [0] : self.hues).flatMap { hue in
                self.backgroundLightnesses.map { CustomColorThemeBuilder.OKLCH(lightness: $0, chroma: chroma, hue: hue).uiColor }
            }
        }
        let accents: [UIColor] = self.hues.flatMap { hue in
            self.accentLightnesses.flatMap { lightness in
                self.accentChromas.map { CustomColorThemeBuilder.OKLCH(lightness: lightness, chroma: $0, hue: hue).uiColor }
            }
        }
        return CustomColorThemeBuilder.Seeds.Form.allCases.flatMap { form in
            backgrounds.flatMap { background in
                accents.map { CustomColorThemeBuilder.Seeds(background: background, accent: $0, form: form) }
            }
        }
    }

    private func adversarialVariants(of base: CustomColorThemeBuilder.Seeds) -> [CustomColorThemeBuilder.Seeds] {
        let extremes: [UIColor] = [base.background, base.accent, UIColor(rgb: 0xFFFFFF), UIColor(rgb: 0x000000)]
        let setters: [(inout CustomColorThemeBuilder.Seeds, UIColor) -> Void] = [
            { $0.text = $1 }, { $0.surface = $1 }, { $0.today = $1 },
            { $0.selectedDay = $1 }, { $0.holidayOrWeekEnd = $1 }, { $0.ai = $1 },
        ]
        let single: [CustomColorThemeBuilder.Seeds] = setters.flatMap { setter in
            extremes.map { color -> CustomColorThemeBuilder.Seeds in
                var seeds = base
                setter(&seeds, color)
                return seeds
            }
        }
        let allSame: [CustomColorThemeBuilder.Seeds] = extremes.map { color -> CustomColorThemeBuilder.Seeds in
            var seeds = base
            setters.forEach { $0(&seeds, color) }
            return seeds
        }
        let mixed: CustomColorThemeBuilder.Seeds = {
            var seeds = base
            seeds.text = base.background
            seeds.surface = base.accent
            seeds.today = UIColor(rgb: 0xFFFFFF)
            seeds.selectedDay = UIColor(rgb: 0x000000)
            seeds.holidayOrWeekEnd = base.background
            return seeds
        }()
        return single + allSame + [mixed]
    }

    private func report(_ failures: [Failure], total: Int) -> Comment {
        let perCheck: [String: Int] = failures.reduce(into: [:]) { $0[$1.check, default: 0] += 1 }
        let summary: String = perCheck.sorted { $0.value > $1.value }
            .map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        let samples: String = failures.prefix(30)
            .map { "[\($0.check) \(String(format: "%.2f", Double($0.ratio)))] \($0.seedsDescription)" }
            .joined(separator: "\n")
        return "\(failures.count)/\(total) 실패 — \(summary)\n\(samples)"
    }


    @Test("격자 A — 필수 시드만 넣은 모든 조합이 보정 뒤 대비 20검사를 넘는다")
    func grid_requiredSeedsOnly_passesAllContrastChecks() {
        let grid: [CustomColorThemeBuilder.Seeds] = self.requiredSeedsGrid()
        let failures: [Failure] = grid.flatMap { self.failures(of: $0) }
        #expect(failures.isEmpty, self.report(failures, total: grid.count))
    }

    @Test("격자 B — 선택 시드에 적대값을 넣어도 대비 20검사를 넘는다")
    func grid_adversarialOptionalSeeds_passesAllContrastChecks() {
        let stride: Int = 97
        let bases: [CustomColorThemeBuilder.Seeds] = self.requiredSeedsGrid()
            .enumerated().filter { $0.offset % stride == 0 }.map { $0.element }
        let grid: [CustomColorThemeBuilder.Seeds] = bases.flatMap { self.adversarialVariants(of: $0) }
        let failures: [Failure] = grid.flatMap { self.failures(of: $0) }
        #expect(failures.isEmpty, self.report(failures, total: grid.count))
    }
}


private extension CustomColorThemeBuilder.Seeds {

    var description: String {
        let optionals: [String] = [
            ("text", text), ("surface", surface), ("today", today),
            ("selectedDay", selectedDay), ("holidayOrWeekEnd", holidayOrWeekEnd), ("ai", ai),
        ].compactMap { pair in pair.1.map { "\(pair.0)=\($0.rgbHex)" } }
        return (["bg=\(background.rgbHex)", "accent=\(accent.rgbHex)", "form=\(form.rawValue)"] + optionals)
            .joined(separator: " ")
    }
}


private extension UIColor {

    func contrastRatio(with other: UIColor) -> CGFloat {
        return CustomColorThemeBuilder.ColorMath().contrastRatio(self, other)
    }

    var rgbHex: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let bytes: [Int] = [red, green, blue].map { Int((max(0, min(1, $0)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", bytes[0], bytes[1], bytes[2])
    }
}
