//
//  ColorSet.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/05.
//

import UIKit
import Domain

// MARK: - event tag color set

public struct EventTagColorSet: Equatable {
    
    public let holiday: UIColor
    public let defaultColor: UIColor
    
    public init(holiday: UIColor, defaultColor: UIColor) {
        self.holiday = holiday
        self.defaultColor = defaultColor
    }
    
    public init(_ setting: DefaultEventTagColorSetting) {
        self.holiday = UIColor.from(hex: setting.holiday) ?? .clear
        self.defaultColor = UIColor.from(hex: setting.default) ?? .clear
    }
}

// MARK: - ColorSet

public protocol ColorSet: Sendable {
    
    // calendar component
    var weekDayText: UIColor { get }
    var weekEndText: UIColor { get }
    var dayBackground: UIColor { get }
    var selectedDayBackground: UIColor { get }
    var selectedDayText: UIColor { get }
    var holidayText: UIColor { get }
    var todayBackground: UIColor { get }
    var eventText: UIColor { get }
    var eventTextSelected: UIColor { get }
    var holidayOrWeekEndWithAccent: UIColor { get }
    var uncompletedTodo: UIColor { get }
    
    // normal text color
    var text0: UIColor { get }
    var text1: UIColor { get }
    var text2: UIColor { get }
    var placeHolder: UIColor { get }
    var text0_inverted: UIColor { get }
    
    // normal button colors
    var primaryBtnBackground: UIColor { get }
    var primaryBtnText: UIColor { get }
    var secondaryBtnBackground: UIColor { get }
    var secondaryBtnText: UIColor { get }
    var negativeBtnBackground: UIColor { get }
    var negativeBtnText: UIColor { get }
    
    // accent colors
    var accent: UIColor { get }
    var accentInfo: UIColor { get }
    var accentWarn: UIColor { get }
    var accentAI: UIColor { get }

    // AI 음성 입력 중 입력 바 배경 (그라데이션 stops — NeonListeningBorder와 같은 팔레트)
    var aiListeningBackground: [UIColor] { get }

    // AI chat bubble (유저 메시지 말풍선)
    var aiUserBubbleBackground: UIColor { get }
    var aiUserBubbleText: UIColor { get }

    // line + background
    var line: UIColor { get }
    var bg0: UIColor { get }
    var bg1: UIColor { get }
    var bg2: UIColor { get }

    var isLightTheme: Bool { get }
}

extension ColorSet {

    public var isLightTheme: Bool {
        return self.bg0.isLight
    }
}

