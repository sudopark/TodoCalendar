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
    var event: UIColor { get }
    var eventSelected: UIColor { get }
    var calendarAccentColor: UIColor { get }
    
    var normalText: UIColor { get }
    var subNormalText: UIColor { get }
    var subSubNormalText: UIColor { get }
    
    var eventList: UIColor { get }
    
    var primaryBtnBackground: UIColor { get }
    var primaryBtnText: UIColor { get }
    var secondaryBtnBackground: UIColor { get }
    var secondaryBtnText: UIColor { get }
    var negativeBtnBackground: UIColor { get }
    var negativeBtnText: UIColor { get }
    
    var accent: UIColor { get }
    var accentOrange: UIColor { get }
    
    var white: UIColor { get }
    var line: UIColor { get }
    
    var background: UIColor { get }
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
    public let event: UIColor = UIColor(rgb: 0x45454a)
    public let eventSelected: UIColor = UIColor.white
    public let calendarAccentColor: UIColor = UIColor.red
    
    public let normalText: UIColor = UIColor(rgb: 0x323232)
    public let subNormalText: UIColor = UIColor(rgb: 0x646464)
    public let subSubNormalText: UIColor = UIColor(rgb: 0x969696)
    
    public let eventList: UIColor = UIColor(rgb: 0xf4f4f4)
    
    public let primaryBtnBackground: UIColor = .systemBlue
    public let primaryBtnText: UIColor = .white
    public var secondaryBtnBackground: UIColor { .systemGray5 }
    public var secondaryBtnText: UIColor { self.normalText }
    public let negativeBtnBackground: UIColor = .systemRed
    public let negativeBtnText: UIColor = .white
    
    public let accent: UIColor = .systemBlue
    public let accentOrange: UIColor = UIColor(rgb: 0xff7417)
    
    public let white: UIColor = .white
    public let line: UIColor = UIColor.black.withAlphaComponent(0.2)
    
    public let background: UIColor = .white
    
    public init() { }
}
