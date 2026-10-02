//
//  CustomColorTheme+Definition.swift
//  CommonPresentation
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain


extension CustomColorTheme {

    var hasReadableRequiredSeeds: Bool {
        return UIColor.from(hex: self.seeds.background) != nil
            && UIColor.from(hex: self.seeds.accent) != nil
    }

    public func definition() -> ColorThemeDefinition? {
        guard let background = UIColor.from(hex: self.seeds.background),
              let accent = UIColor.from(hex: self.seeds.accent)
        else { return nil }

        let seeds = CustomColorThemeBuilder.Seeds(
            background: background,
            accent: accent,
            text: self.seeds.text.flatMap { UIColor.from(hex: $0) },
            surface: self.seeds.surface.flatMap { UIColor.from(hex: $0) },
            today: self.seeds.today.flatMap { UIColor.from(hex: $0) },
            selectedDay: self.seeds.selectedDay.flatMap { UIColor.from(hex: $0) },
            holidayOrWeekEnd: self.seeds.holidayOrWeekEnd.flatMap { UIColor.from(hex: $0) },
            ai: self.seeds.ai.flatMap { UIColor.from(hex: $0) },
            form: CustomColorThemeBuilder.Seeds.Form(rawValue: self.seeds.form.rawValue) ?? .filled
        )
        return CustomColorThemeBuilder().build(name: self.name, seeds: seeds)
    }
}


extension ColorThemeDefinition {

    public var exportedColors: [String: String] {
        let required: [String: UIColor] = [
            "bg0": self.bg0,
            "bg1": self.bg1,
            "todayBackground": self.todayBackground,
            "line": self.line,
            "text0": self.text0,
            "text1": self.text1,
            "accent": self.accent,
            "selectedDayBackground": self.selectedDayBackground,
            "selectedDayText": self.selectedDayText,
            "holidayOrWeekEndWithAccent": self.holidayOrWeekEndWithAccent,
            "bg2": self.bg2,
            "text2": self.text2,
            "placeHolder": self.placeHolder,
            "secondaryBtnBackground": self.secondaryBtnBackground,
            "accentAI": self.accentAI
        ]
        let listening: [String: UIColor] = self.aiListeningBackgroundBase.enumerated()
            .reduce(into: [:]) { $0["aiListeningBackgroundBase\($1.offset)"] = $1.element }
        let overrides: [String: UIColor?] = [
            "eventTextOverride": self.eventTextOverride,
            "primaryBtnTextOverride": self.primaryBtnTextOverride,
            "weekDayTextOverride": self.weekDayTextOverride,
            "holidayTextOverride": self.holidayTextOverride,
            "weekEndTextOverride": self.weekEndTextOverride,
            "eventTextSelectedOverride": self.eventTextSelectedOverride,
            "aiUserBubbleBackgroundOverride": self.aiUserBubbleBackgroundOverride,
            "negativeBtnBackgroundOverride": self.negativeBtnBackgroundOverride
        ]
        let present: [String: UIColor] = overrides.compactMapValues { $0 }
        return required
            .merging(listening) { $1 }
            .merging(present) { $1 }
            .mapValues { $0.rgbHexString }
    }
}


private extension UIColor {

    var rgbHexString: String {
        var (red, green, blue, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded())
        )
    }
}
