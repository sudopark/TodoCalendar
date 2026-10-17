//
//  ColorSetKeys+Definition.swift
//  CommonPresentation
//
//  Created by sudo.park on 9/28/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain


extension ColorSetKeys {

    public func convert(isSystemDarkTheme: Bool) -> any ColorSet {
        return self.convert(isSystemDarkTheme: isSystemDarkTheme, customColorTheme: nil)
    }

    public func convert(
        isSystemDarkTheme: Bool,
        customColorTheme: CustomColorTheme?
    ) -> any ColorSet {
        switch self {
        case .systemTheme where isSystemDarkTheme:
            return Constant.defaultDark
        case .systemTheme:
            return Constant.defaultLight
        case .defaultLight:
            return Constant.defaultLight
        case .defaultDark:
            return Constant.defaultDark
        case .appTheme(let key):
            return key.definition
        case .custom(let id):
            return customColorTheme.flatMap { $0.uuid == id ? $0.definition() : nil }
                ?? ColorSetKeys.systemTheme.convert(isSystemDarkTheme: isSystemDarkTheme)
        }
    }
}


private enum Constant {

    static let defaultLight: ColorThemeDefinition = ColorThemeDefinition(
        name: .default(localizeKey: "setting.appearance.calendar.colorTheme::light"),
        bg0: .white,
        bg1: UIColor(rgb: 0xf3f4f7),
        todayBackground: UIColor(rgb: 0xf4f4f4),
        line: UIColor.black.withAlphaComponent(0.2),
        text0: UIColor(rgb: 0x323232),
        text1: UIColor(rgb: 0x646464),
        accent: .systemBlue,
        selectedDayBackground: UIColor(rgb: 0x303646),
        selectedDayText: .white,
        holidayOrWeekEndWithAccent: .red,
        bg2: UIColor(rgb: 0xf4f4f4),
        text2: UIColor(rgb: 0x969696),
        placeHolder: UIColor(rgb: 0xccd0dc),
        secondaryBtnBackground: .systemGray5,
        accentAI: UIColor(rgb: 0x6272a4),
        aiListeningBackgroundBase: [
            UIColor(rgb: 0xbd93f9), UIColor(rgb: 0xff79c6), UIColor(rgb: 0x8be9fd)
        ],
        eventTextOverride: UIColor(rgb: 0x45454a),
        holidayTextOverride: UIColor(rgb: 0x233238),
        aiUserBubbleBackgroundOverride: UIColor(rgb: 0x44475a),
        negativeBtnBackgroundOverride: .systemRed
    )

    static let defaultDark: ColorThemeDefinition = ColorThemeDefinition(
        name: .default(localizeKey: "setting.appearance.calendar.colorTheme::dark"),
        bg0: UIColor(rgb: 0x18181a),
        bg1: UIColor(rgb: 0x45454a),
        todayBackground: UIColor(rgb: 0x45454a),
        line: UIColor.white.withAlphaComponent(0.2),
        text0: UIColor(rgb: 0xf8f8f9),
        text1: UIColor(rgb: 0xf1f1f1),
        accent: .systemBlue,
        selectedDayBackground: UIColor(rgb: 0xccd0dc),
        selectedDayText: UIColor(rgb: 0x1a153d),
        holidayOrWeekEndWithAccent: .red,
        bg2: UIColor(rgb: 0x393c3c),
        text2: UIColor(rgb: 0xe5e5e4),
        placeHolder: UIColor(rgb: 0xa0a0a7),
        secondaryBtnBackground: UIColor(rgb: 0x71717a),
        accentAI: UIColor(rgb: 0x6272a4),
        aiListeningBackgroundBase: [
            UIColor(rgb: 0xbd93f9), UIColor(rgb: 0xff79c6), UIColor(rgb: 0x8be9fd)
        ],
        eventTextOverride: UIColor(rgb: 0xe2e4eb),
        weekDayTextOverride: UIColor(rgb: 0xf3f4f7),
        holidayTextOverride: UIColor(rgb: 0xf4f2f8),
        weekEndTextOverride: UIColor(rgb: 0xe2e4eb),
        eventTextSelectedOverride: UIColor(rgb: 0x151131),
        negativeBtnBackgroundOverride: .systemRed
    )
}
