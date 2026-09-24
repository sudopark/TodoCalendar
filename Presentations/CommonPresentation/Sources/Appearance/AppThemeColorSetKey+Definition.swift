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
                secondaryBtnBackground: UIColor(rgb: 0xDAD9D6),
                accentAI: UIColor(rgb: 0xBB5380),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x9C5FB5), UIColor(rgb: 0xBB5380), UIColor(rgb: 0xC1573D)
                ]
            )
        case .ruby:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0xFDFCFD),
                bg1: UIColor(rgb: 0xFEEAED),
                todayBackground: UIColor(rgb: 0xFFCED6),
                line: UIColor(rgb: 0xFEEAED),
                text0: UIColor(rgb: 0x64172B),
                text1: UIColor(rgb: 0xCA244D),
                accent: UIColor(rgb: 0xE54666),
                selectedDayBackground: UIColor(rgb: 0xCA244D),
                selectedDayText: UIColor(rgb: 0xFFFFFF),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xCE2C31),
                bg2: UIColor(rgb: 0xFFCED6),
                text2: UIColor(rgb: 0xDB6380),
                placeHolder: UIColor(rgb: 0xEFB1BF),
                secondaryBtnBackground: UIColor(rgb: 0xFFCED6),
                accentAI: UIColor(rgb: 0xBB4FA1),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x8C63D4), UIColor(rgb: 0xBB4FA1), UIColor(rgb: 0xCF4957)
                ],
                eventTextOverride: UIColor(rgb: 0xB72247)
            )
        case .crimson:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0xFDFCFD),
                bg1: UIColor(rgb: 0xF2EFF3),
                todayBackground: UIColor(rgb: 0xFFE9F0),
                line: UIColor(rgb: 0xDBD8E0),
                text0: UIColor(rgb: 0x211F26),
                text1: UIColor(rgb: 0x65636D),
                accent: UIColor(rgb: 0xE93D82),
                selectedDayBackground: UIColor(rgb: 0xCB1D63),
                selectedDayText: UIColor(rgb: 0xFFFFFF),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xCE2C31),
                bg2: UIColor(rgb: 0xFAF9FB),
                text2: UIColor(rgb: 0x8C8A93),
                placeHolder: UIColor(rgb: 0xC5C2CA),
                secondaryBtnBackground: UIColor(rgb: 0xDBD8E0),
                accentAI: UIColor(rgb: 0xBD49B2),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x8562E7), UIColor(rgb: 0xBD49B2), UIColor(rgb: 0xD93D61)
                ]
            )
        case .pink:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0xF0F0F0),
                bg1: UIColor(rgb: 0xFFFFFF),
                todayBackground: UIColor(rgb: 0xFEE9F5),
                line: UIColor(rgb: 0xD9D9D9),
                text0: UIColor(rgb: 0x202020),
                text1: UIColor(rgb: 0x646464),
                accent: UIColor(rgb: 0xD6409F),
                selectedDayBackground: UIColor(rgb: 0xC2298A),
                selectedDayText: UIColor(rgb: 0xFFFFFF),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xCE2C31),
                bg2: UIColor(rgb: 0xF9F9F9),
                text2: UIColor(rgb: 0x8B8B8B),
                placeHolder: UIColor(rgb: 0xC3C3C3),
                secondaryBtnBackground: UIColor(rgb: 0xD9D9D9),
                accentAI: UIColor(rgb: 0xB24BC3),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x7067EF), UIColor(rgb: 0xB24BC3), UIColor(rgb: 0xD53876)
                ]
            )
        case .plum:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0xFDFCFD),
                bg1: UIColor(rgb: 0xFBEBFB),
                todayBackground: UIColor(rgb: 0xF2D1F3),
                line: UIColor(rgb: 0xFBEBFB),
                text0: UIColor(rgb: 0x53195D),
                text1: UIColor(rgb: 0x953EA3),
                accent: UIColor(rgb: 0xAB4ABA),
                selectedDayBackground: UIColor(rgb: 0x953EA3),
                selectedDayText: UIColor(rgb: 0xFFFFFF),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xCA244D),
                bg2: UIColor(rgb: 0xF2D1F3),
                text2: UIColor(rgb: 0xB574BE),
                placeHolder: UIColor(rgb: 0xDCB7E0),
                secondaryBtnBackground: UIColor(rgb: 0xF2D1F3),
                accentAI: UIColor(rgb: 0x9851D4),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x436EED), UIColor(rgb: 0x9851D4), UIColor(rgb: 0xC63992)
                ],
                eventTextOverride: UIColor(rgb: 0x913C9F)
            )
        case .purple:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0xFCFCFD),
                bg1: UIColor(rgb: 0xF0F0F3),
                todayBackground: UIColor(rgb: 0xF7EDFE),
                line: UIColor(rgb: 0xD9D9E0),
                text0: UIColor(rgb: 0x1C2024),
                text1: UIColor(rgb: 0x60646C),
                accent: UIColor(rgb: 0x8E4EC6),
                selectedDayBackground: UIColor(rgb: 0x8145B5),
                selectedDayText: UIColor(rgb: 0xFFFFFF),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xCE2C31),
                bg2: UIColor(rgb: 0xF9F9FB),
                text2: UIColor(rgb: 0x898C93),
                placeHolder: UIColor(rgb: 0xC3C3CA),
                secondaryBtnBackground: UIColor(rgb: 0xD9D9E0),
                accentAI: UIColor(rgb: 0x8754DB),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x0D72E8), UIColor(rgb: 0x8754DB), UIColor(rgb: 0xBB3AA1)
                ]
            )
        case .violet:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0xF0F0F3),
                bg1: UIColor(rgb: 0xFFFFFF),
                todayBackground: UIColor(rgb: 0xF4F0FE),
                line: UIColor(rgb: 0xD9D9E0),
                text0: UIColor(rgb: 0x1C2024),
                text1: UIColor(rgb: 0x60646C),
                accent: UIColor(rgb: 0x6E56CF),
                selectedDayBackground: UIColor(rgb: 0x6550B9),
                selectedDayText: UIColor(rgb: 0xFFFFFF),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xCA244D),
                bg2: UIColor(rgb: 0xF9F9FB),
                text2: UIColor(rgb: 0x898C93),
                placeHolder: UIColor(rgb: 0xC3C3CA),
                secondaryBtnBackground: UIColor(rgb: 0xD9D9E0),
                accentAI: UIColor(rgb: 0x7458E0),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x1079C5), UIColor(rgb: 0x7458E0), UIColor(rgb: 0xAF3DAF)
                ]
            )
        case .indigo:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0xFCFCFD),
                bg1: UIColor(rgb: 0xEDF2FE),
                todayBackground: UIColor(rgb: 0xD2DEFF),
                line: UIColor(rgb: 0xEDF2FE),
                text0: UIColor(rgb: 0x1F2D5C),
                text1: UIColor(rgb: 0x3A5BC7),
                accent: UIColor(rgb: 0x3E63DD),
                selectedDayBackground: UIColor(rgb: 0x3A5BC7),
                selectedDayText: UIColor(rgb: 0xFFFFFF),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xCE2C31),
                bg2: UIColor(rgb: 0xD2DEFF),
                text2: UIColor(rgb: 0x7088D8),
                placeHolder: UIColor(rgb: 0xB7C4EE),
                secondaryBtnBackground: UIColor(rgb: 0xD2DEFF),
                accentAI: UIColor(rgb: 0x5760E9),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x0C7EAE), UIColor(rgb: 0x5760E9), UIColor(rgb: 0xA042C5)
                ],
                eventTextOverride: UIColor(rgb: 0x395AC5)
            )
        case .blue:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0xFCFCFC),
                bg1: UIColor(rgb: 0xF0F0F0),
                todayBackground: UIColor(rgb: 0xE6F4FE),
                line: UIColor(rgb: 0xD9D9D9),
                text0: UIColor(rgb: 0x202020),
                text1: UIColor(rgb: 0x646464),
                accent: UIColor(rgb: 0x0090FF),
                selectedDayBackground: UIColor(rgb: 0x0D74CE),
                selectedDayText: UIColor(rgb: 0xFFFFFF),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xCA244D),
                bg2: UIColor(rgb: 0xF9F9F9),
                text2: UIColor(rgb: 0x8B8B8B),
                placeHolder: UIColor(rgb: 0xC3C3C3),
                secondaryBtnBackground: UIColor(rgb: 0xD9D9D9),
                accentAI: UIColor(rgb: 0x327BFD),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x0092B2), UIColor(rgb: 0x327BFD), UIColor(rgb: 0x9A5BE9)
                ]
            )
        case .jade:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0xEEF1F0),
                bg1: UIColor(rgb: 0xFFFFFF),
                todayBackground: UIColor(rgb: 0xE6F7ED),
                line: UIColor(rgb: 0xD7DAD9),
                text0: UIColor(rgb: 0x1A211E),
                text1: UIColor(rgb: 0x5F6563),
                accent: UIColor(rgb: 0x208368),
                selectedDayBackground: UIColor(rgb: 0x208368),
                selectedDayText: UIColor(rgb: 0xFFFFFF),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xCE2C31),
                bg2: UIColor(rgb: 0xF7F9F8),
                text2: UIColor(rgb: 0x888D8B),
                placeHolder: UIColor(rgb: 0xC1C4C3),
                secondaryBtnBackground: UIColor(rgb: 0xD7DAD9),
                accentAI: UIColor(rgb: 0x4573A2),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x147D8D), UIColor(rgb: 0x4573A2), UIColor(rgb: 0x6F66A0)
                ]
            )
        case .scarlet:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0xFCFDFC),
                bg1: UIColor(rgb: 0xFEEBEC),
                todayBackground: UIColor(rgb: 0xFFCDCE),
                line: UIColor(rgb: 0xFEEBEC),
                text0: UIColor(rgb: 0x641723),
                text1: UIColor(rgb: 0xCE2C31),
                accent: UIColor(rgb: 0xE5484D),
                selectedDayBackground: UIColor(rgb: 0xCE2C31),
                selectedDayText: UIColor(rgb: 0xFFFFFF),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xCB1D63),
                bg2: UIColor(rgb: 0xFFCDCE),
                text2: UIColor(rgb: 0xDC6569),
                placeHolder: UIColor(rgb: 0xF0B3B5),
                secondaryBtnBackground: UIColor(rgb: 0xFFCDCE),
                accentAI: UIColor(rgb: 0xBB5092),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x9360C7), UIColor(rgb: 0xBB5092), UIColor(rgb: 0xC94F4B)
                ],
                eventTextOverride: UIColor(rgb: 0xB5272E)
            )
        case .midnight:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0x111113),
                bg1: UIColor(rgb: 0x182449),
                todayBackground: UIColor(rgb: 0x253974),
                line: UIColor(rgb: 0x182449),
                text0: UIColor(rgb: 0xD6E1FF),
                text1: UIColor(rgb: 0x9EB1FF),
                accent: UIColor(rgb: 0x3E63DD),
                selectedDayBackground: UIColor(rgb: 0x9EB1FF),
                selectedDayText: UIColor(rgb: 0x111113),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xFF949D),
                bg2: UIColor(rgb: 0x253974),
                text2: UIColor(rgb: 0x5C6CA6),
                placeHolder: UIColor(rgb: 0x34426F),
                secondaryBtnBackground: UIColor(rgb: 0x253974),
                accentAI: UIColor(rgb: 0x5760E9),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x0C7EAE), UIColor(rgb: 0x5760E9), UIColor(rgb: 0xA042C5)
                ]
            )
        case .ink:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0x111111),
                bg1: UIColor(rgb: 0x111111),
                todayBackground: UIColor(rgb: 0x222222),
                line: UIColor(rgb: 0x3A3A3A),
                text0: UIColor(rgb: 0xEEEEEE),
                text1: UIColor(rgb: 0xB4B4B4),
                accent: UIColor(rgb: 0xB4B4B4),
                selectedDayBackground: UIColor(rgb: 0xEEEEEE),
                selectedDayText: UIColor(rgb: 0x111111),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xFF977D),
                bg2: UIColor(rgb: 0x191919),
                text2: UIColor(rgb: 0x606060),
                placeHolder: UIColor(rgb: 0x3C3C3C),
                secondaryBtnBackground: UIColor(rgb: 0x3A3A3A),
                accentAI: UIColor(rgb: 0x9E91D0),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x739FD4), UIColor(rgb: 0x9E91D0), UIColor(rgb: 0xBF86B4)
                ],
                primaryBtnTextOverride: UIColor(rgb: 0x111111)
            )
        case .abyss:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0x101211),
                bg1: UIColor(rgb: 0x202221),
                todayBackground: UIColor(rgb: 0x0F2E22),
                line: UIColor(rgb: 0x373B39),
                text0: UIColor(rgb: 0xECEEED),
                text1: UIColor(rgb: 0xADB5B2),
                accent: UIColor(rgb: 0x29A383),
                selectedDayBackground: UIColor(rgb: 0x1FD8A4),
                selectedDayText: UIColor(rgb: 0x101211),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xFF92AD),
                bg2: UIColor(rgb: 0x171918),
                text2: UIColor(rgb: 0x666C69),
                placeHolder: UIColor(rgb: 0x3D413F),
                secondaryBtnBackground: UIColor(rgb: 0x373B39),
                accentAI: UIColor(rgb: 0x4A87B3),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x269198), UIColor(rgb: 0x4A87B3), UIColor(rgb: 0x7879B7)
                ]
            )
        case .wine:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0x121113),
                bg1: UIColor(rgb: 0x3A141E),
                todayBackground: UIColor(rgb: 0x5E1A2E),
                line: UIColor(rgb: 0x3A141E),
                text0: UIColor(rgb: 0xFED2E1),
                text1: UIColor(rgb: 0xFF949D),
                accent: UIColor(rgb: 0xE54666),
                selectedDayBackground: UIColor(rgb: 0xFF949D),
                selectedDayText: UIColor(rgb: 0x121113),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xFF977D),
                bg2: UIColor(rgb: 0x5E1A2E),
                text2: UIColor(rgb: 0x9E555F),
                placeHolder: UIColor(rgb: 0x642F39),
                secondaryBtnBackground: UIColor(rgb: 0x5E1A2E),
                accentAI: UIColor(rgb: 0xBB4FA1),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x8C63D4), UIColor(rgb: 0xBB4FA1), UIColor(rgb: 0xCF4957)
                ]
            )
        case .dusk:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0x121113),
                bg1: UIColor(rgb: 0x121113),
                todayBackground: UIColor(rgb: 0x351A35),
                line: UIColor(rgb: 0x3C393F),
                text0: UIColor(rgb: 0xEEEEF0),
                text1: UIColor(rgb: 0xB5B2BC),
                accent: UIColor(rgb: 0xAB4ABA),
                selectedDayBackground: UIColor(rgb: 0xE796F3),
                selectedDayText: UIColor(rgb: 0x121113),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xFF949D),
                bg2: UIColor(rgb: 0x1A191B),
                text2: UIColor(rgb: 0x625F66),
                placeHolder: UIColor(rgb: 0x3E3B41),
                secondaryBtnBackground: UIColor(rgb: 0x3C393F),
                accentAI: UIColor(rgb: 0x9851D4),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x436EED), UIColor(rgb: 0x9851D4), UIColor(rgb: 0xC63992)
                ]
            )
        case .amethyst:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0x111113),
                bg1: UIColor(rgb: 0x291F43),
                todayBackground: UIColor(rgb: 0x3C2E69),
                line: UIColor(rgb: 0x291F43),
                text0: UIColor(rgb: 0xE2DDFE),
                text1: UIColor(rgb: 0xBAA7FF),
                accent: UIColor(rgb: 0x6E56CF),
                selectedDayBackground: UIColor(rgb: 0xBAA7FF),
                selectedDayText: UIColor(rgb: 0x111113),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xFF949D),
                bg2: UIColor(rgb: 0x3C2E69),
                text2: UIColor(rgb: 0x7364A3),
                placeHolder: UIColor(rgb: 0x483C6B),
                secondaryBtnBackground: UIColor(rgb: 0x3C2E69),
                accentAI: UIColor(rgb: 0x7458E0),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x1079C5), UIColor(rgb: 0x7458E0), UIColor(rgb: 0xAF3DAF)
                ]
            )
        case .camellia:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0x121113),
                bg1: UIColor(rgb: 0x232225),
                todayBackground: UIColor(rgb: 0x381525),
                line: UIColor(rgb: 0x3C393F),
                text0: UIColor(rgb: 0xEEEEF0),
                text1: UIColor(rgb: 0xB5B2BC),
                accent: UIColor(rgb: 0xE93D82),
                selectedDayBackground: UIColor(rgb: 0xFF92AD),
                selectedDayText: UIColor(rgb: 0x121113),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xFF977D),
                bg2: UIColor(rgb: 0x1A191B),
                text2: UIColor(rgb: 0x6E6B72),
                placeHolder: UIColor(rgb: 0x424046),
                secondaryBtnBackground: UIColor(rgb: 0x3C393F),
                accentAI: UIColor(rgb: 0xBD49B2),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x8562E7), UIColor(rgb: 0xBD49B2), UIColor(rgb: 0xD93D61)
                ]
            )
        case .sunset:
            return ColorThemeDefinition(
                name: self.themeName,
                bg0: UIColor(rgb: 0x111110),
                bg1: UIColor(rgb: 0x222221),
                todayBackground: UIColor(rgb: 0x391714),
                line: UIColor(rgb: 0x3B3A37),
                text0: UIColor(rgb: 0xEEEEEC),
                text1: UIColor(rgb: 0xB5B3AD),
                accent: UIColor(rgb: 0xE54D2E),
                selectedDayBackground: UIColor(rgb: 0xFF977D),
                selectedDayText: UIColor(rgb: 0x111110),
                holidayOrWeekEndWithAccent: UIColor(rgb: 0xFF949D),
                bg2: UIColor(rgb: 0x191918),
                text2: UIColor(rgb: 0x6D6C67),
                placeHolder: UIColor(rgb: 0x42403D),
                secondaryBtnBackground: UIColor(rgb: 0x3B3A37),
                accentAI: UIColor(rgb: 0xBB5380),
                aiListeningBackgroundBase: [
                    UIColor(rgb: 0x9C5FB5), UIColor(rgb: 0xBB5380), UIColor(rgb: 0xC1573D)
                ]
            )
        }
    }

    private var themeName: ColorThemeName {
        return .default(
            localizeKey: "setting.appearance.calendar.colorTheme::\(self.rawValue)"
        )
    }
}
