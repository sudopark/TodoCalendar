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
    
    var key: ColorSetKeys { get }
    
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
    
    // normal text color
    var text0: UIColor { get }
    var text1: UIColor { get }
    var text2: UIColor { get }
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
    
    // line + background
    var line: UIColor { get }
    var bg0: UIColor { get }
    var bg1: UIColor { get }
}


// MARK: - default light

public struct DefaultLightColorSet: ColorSet {
    
    public let key: ColorSetKeys = .defaultLight

    // calendar component
    public let weekDayText: UIColor = UIColor(rgb: 0x323232)
    public let weekEndText: UIColor = UIColor(rgb: 0x646464)
    public let dayBackground: UIColor = UIColor.white
    public let selectedDayBackground: UIColor = UIColor(rgb: 0x303646)
    public let selectedDayText: UIColor = UIColor.white
    public let holidayText: UIColor = UIColor(rgb: 0x233238)
    public let todayBackground: UIColor = UIColor(rgb: 0xf4f4f4)
    public let eventText: UIColor = UIColor(rgb: 0x45454a)
    public let eventTextSelected: UIColor = UIColor.white
    public let holidayOrWeekEndWithAccent: UIColor = UIColor.red
    
    // normal text color
    public let text0: UIColor = UIColor(rgb: 0x323232)
    public let text1: UIColor = UIColor(rgb: 0x646464)
    public let text2: UIColor = UIColor(rgb: 0x969696)
    public let text0_inverted: UIColor = .white
    
    // normal button colors
    public let primaryBtnBackground: UIColor = .systemBlue
    public let primaryBtnText: UIColor = .white
    public var secondaryBtnBackground: UIColor { .systemGray5 }
    public var secondaryBtnText: UIColor { self.text0 }
    public let negativeBtnBackground: UIColor = .systemRed
    public let negativeBtnText: UIColor = .white
    
    // accent colors
    public let accent: UIColor = .systemBlue
    public let accentInfo: UIColor = UIColor(rgb: 0xff7417)
    public let accentWarn: UIColor = UIColor(rgb: 0xea4444)
    
    
    // line + background
    public let line: UIColor = UIColor.black.withAlphaComponent(0.2)
    public let bg0: UIColor = .white
    public let bg1: UIColor = UIColor(rgb: 0xf4f4f4)
    
    public init() { }
}


// MARK: - default dark

public struct DefaultDarkColorSet: ColorSet {
    
    public let key: ColorSetKeys = .defaultDark

    // calendar component
    public let weekDayText: UIColor = UIColor(rgb: 0xf3f4f7)
    public let weekEndText: UIColor = UIColor(rgb: 0xe2e4eb)
    public let dayBackground: UIColor = UIColor(rgb: 0x2e2a22)
    public let selectedDayBackground: UIColor = UIColor(rgb: 0xf8f8f9)
    public let selectedDayText: UIColor = UIColor(rgb: 0x1a153d)
    public let holidayText: UIColor = UIColor(rgb: 0xf4f2f8)
    public let todayBackground: UIColor = UIColor(rgb: 0x626e8e)
    public let eventText: UIColor = UIColor(rgb: 0xe2e4eb)
    public let eventTextSelected: UIColor = UIColor(rgb: 0x151131)
    public let holidayOrWeekEndWithAccent: UIColor = UIColor.red
    
    // normal text color
    public let text0: UIColor = UIColor(rgb: 0xf8f8f9)
    public let text1: UIColor = UIColor(rgb: 0xf1f1f1)
    public let text2: UIColor = UIColor(rgb: 0xe5e5e4)
    public let text0_inverted: UIColor = UIColor(rgb: 0x393c3c)
    
    // normal button colors
    public let primaryBtnBackground: UIColor = .systemBlue
    public let primaryBtnText: UIColor = .white
    public let secondaryBtnBackground: UIColor = UIColor(rgb: 0x71717a)
    public var secondaryBtnText: UIColor { self.text0 }
    public let negativeBtnBackground: UIColor = .systemRed
    public let negativeBtnText: UIColor = .white
    
    // accent colors
    public let accent: UIColor = .systemBlue
    public let accentInfo: UIColor = UIColor(rgb: 0xff7417)
    public let accentWarn: UIColor = UIColor(rgb: 0xea4444)
    
    
    // line + background
    public let line: UIColor = UIColor.white.withAlphaComponent(0.2)
    public let bg0: UIColor = UIColor(rgb: 0x18181a)
    public let bg1: UIColor = UIColor(rgb: 0x393c3c)
    
    public init() { }
}
