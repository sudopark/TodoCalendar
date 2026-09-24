//
//  AppThemeColorSetKey+Definition.swift
//  CommonPresentation
//
//  Created by sudo.park on 9/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain


extension AppThemeColorSetKey {

    public var definition: ColorThemeDefinition {
        switch self {
        case .tomato:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0xF1F0EF),
                bg1: UIColor(rgb: 0xFFFFFF),
                todayBackground: UIColor(rgb: 0xFEEBE7),
                line: UIColor(rgb: 0xDAD9D6),
                text0: UIColor(rgb: 0x21201C),
                text1: UIColor(rgb: 0x63635E),
                accent: UIColor(rgb: 0xE54D2E),
                selectedDayBackground: UIColor(rgb: 0xD13415),
                selectedDayText: UIColor(rgb: 0xFFFFFF),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xCB1D63),
                bg2: UIColor(rgb: 0xF9F9F8),
                text2: UIColor(rgb: 0x8B8B87),
                placeHolder: UIColor(rgb: 0xC4C3C0),
                secondaryBtnBackground: UIColor(rgb: 0xDAD9D6)
            )
        }
    }

    private var themeName: ColorThemeName {
        return .default(
            localizeKey: "setting.appearance.calendar.colorTheme::\(self.rawValue)"
        )
    }
}
