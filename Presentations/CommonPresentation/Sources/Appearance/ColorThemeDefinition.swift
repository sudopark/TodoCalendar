//
//  ColorThemeDefinition.swift
//  CommonPresentation
//
//  Created by sudo.park on 9/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Extensions


// MARK: - ColorThemeName

public enum ColorThemeName: Sendable, Equatable {
    case `default`(localizeKey: String)
    case custom(String)

    public var localized: String {
        switch self {
        case .default(let localizeKey): return localizeKey.localized()
        case .custom(let name): return name
        }
    }
}


// MARK: - ColorThemeDefinition

public struct ColorThemeDefinition: Sendable {

    public let name: ColorThemeName

    // 값 14개는 스펙 §2 의 라인업 10·명시 4 다.
    public let bg0: UIColor
    public let bg1: UIColor
    public let todayBackground: UIColor
    public let line: UIColor
    public let text0: UIColor
    public let text1: UIColor
    public let accent: UIColor
    public let selectedDayBackground: UIColor
    public let selectedDayText: UIColor
    public let holidayOrWeekEndWithAccent: UIColor

    public let bg2: UIColor
    public let text2: UIColor
    public let placeHolder: UIColor
    public let secondaryBtnBackground: UIColor

    public let eventTextOverride: UIColor?
    public let primaryBtnTextOverride: UIColor?

    public init(
        name: ColorThemeName,
        bg0: UIColor,
        bg1: UIColor,
        todayBackground: UIColor,
        line: UIColor,
        text0: UIColor,
        text1: UIColor,
        accent: UIColor,
        selectedDayBackground: UIColor,
        selectedDayText: UIColor,
        holidayOrWeekEndWithAccent: UIColor,
        bg2: UIColor,
        text2: UIColor,
        placeHolder: UIColor,
        secondaryBtnBackground: UIColor,
        eventTextOverride: UIColor? = nil,
        primaryBtnTextOverride: UIColor? = nil
    ) {
        self.name = name
        self.bg0 = bg0
        self.bg1 = bg1
        self.todayBackground = todayBackground
        self.line = line
        self.text0 = text0
        self.text1 = text1
        self.accent = accent
        self.selectedDayBackground = selectedDayBackground
        self.selectedDayText = selectedDayText
        self.holidayOrWeekEndWithAccent = holidayOrWeekEndWithAccent
        self.bg2 = bg2
        self.text2 = text2
        self.placeHolder = placeHolder
        self.secondaryBtnBackground = secondaryBtnBackground
        self.eventTextOverride = eventTextOverride
        self.primaryBtnTextOverride = primaryBtnTextOverride
    }
}


// MARK: - ColorSet

extension ColorThemeDefinition: ColorSet {

    // 관계로 채우는 토큰

    public var dayBackground: UIColor {
        return self.bg0
    }

    public var weekDayText: UIColor {
        return self.text0
    }

    public var holidayText: UIColor {
        return self.text0
    }

    public var weekEndText: UIColor {
        return self.text1
    }

    public var eventText: UIColor {
        return self.eventTextOverride ?? self.text1
    }

    public var eventTextSelected: UIColor {
        return self.selectedDayText
    }

    public var aiUserBubbleBackground: UIColor {
        return self.selectedDayBackground
    }

    public var aiUserBubbleText: UIColor {
        return self.selectedDayText
    }

    public var secondaryBtnText: UIColor {
        return self.text0
    }

    public var primaryBtnBackground: UIColor {
        return self.accent
    }

    public var text0_inverted: UIColor {
        return self.isLightTheme ? self.bg0 : self.bg2
    }

    // 테마와 무관한 토큰

    public var uncompletedTodo: UIColor {
        return Constant.uncompletedTodo
    }

    public var accentInfo: UIColor {
        return Constant.accentInfo
    }

    public var accentWarn: UIColor {
        return Constant.accentWarn
    }

    public var accentAI: UIColor {
        return Constant.accentAI
    }

    public var primaryBtnText: UIColor {
        return self.primaryBtnTextOverride ?? Constant.white
    }

    public var negativeBtnText: UIColor {
        return Constant.white
    }

    public var negativeBtnBackground: UIColor {
        return self.isLightTheme
            ? Constant.negativeBtnBackgroundLight
            : Constant.negativeBtnBackgroundDark
    }

    public var aiListeningBackground: [UIColor] {
        return self.isLightTheme
            ? Constant.aiListeningBackgroundLight
            : Constant.aiListeningBackgroundDark
    }
}


// UIColor.white 는 색공간이 달라 hex 로 만든 흰색과 == 가 false 다.
private enum Constant {

    static let uncompletedTodo: UIColor = UIColor(rgb: 0xea4444)
    static let accentInfo: UIColor = UIColor(rgb: 0xff7417)
    static let accentWarn: UIColor = UIColor(rgb: 0xea4444)
    static let accentAI: UIColor = UIColor(rgb: 0x6272a4)
    static let white: UIColor = UIColor(rgb: 0xffffff)
    static let negativeBtnBackgroundLight: UIColor = UIColor(rgb: 0xff3b30)
    static let negativeBtnBackgroundDark: UIColor = UIColor(rgb: 0xff453a)

    static let aiListeningBackgroundLight: [UIColor] = [
        UIColor(rgb: 0xbd93f9).withAlphaComponent(0.20),
        UIColor(rgb: 0xff79c6).withAlphaComponent(0.13),
        UIColor(rgb: 0x8be9fd).withAlphaComponent(0.20)
    ]
    static let aiListeningBackgroundDark: [UIColor] = [
        UIColor(rgb: 0xbd93f9).withAlphaComponent(0.28),
        UIColor(rgb: 0xff79c6).withAlphaComponent(0.18),
        UIColor(rgb: 0x8be9fd).withAlphaComponent(0.26)
    ]
}
