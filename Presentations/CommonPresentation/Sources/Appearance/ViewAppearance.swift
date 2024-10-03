//
//  ViewAppearance.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/05.
//

import SwiftUI
import Combine
import Domain


public class ViewAppearance: ObservableObject {
    
    public var colorSetKey: ColorSetKeys
    @Published public var tagColors: EventTagColorSet
    @Published public var colorSet: any ColorSet
    @Published public var fontSet: any FontSet
    @Published public var navigationBarId: String = UUID().uuidString
    public func forceReloadNavigationBar() {
        self.navigationBarId = UUID().uuidString
    }
    
    // calendar
    @Published public var accnetDayPolicy: [AccentDays: Bool]
    @Published public var showUnderLineOnEventDay: Bool
    
    // event on calendar
    @Published public var eventOnCalenarTextAdditionalSize: CGFloat
    @Published public var eventOnCalendarIsBold: Bool
    @Published public var eventOnCalendarShowEventTagColor: Bool
    
    // event list
    @Published public var eventTextAdditionalSize: CGFloat
    @Published public var showHoliday: Bool
    @Published public var showLunarCalendarDate: Bool
    @Published public var is24hourForm: Bool
    
    // general
    @Published public var hapticEffectOff: Bool
    @Published public var animationEffectOff: Bool
    
    public init(setting: AppearanceSettings, isSystemDarkTheme: Bool) {
        
        let (calendar, defaultTagColor) = (setting.calendar, setting.defaultTagColor)
        
        self.tagColors = .init(
            holiday: UIColor.from(hex: defaultTagColor.holiday) ?? .clear,
            defaultColor: UIColor.from(hex: defaultTagColor.default) ?? .clear
        )
        self.colorSetKey = calendar.colorSetKey
        self.colorSet = calendar.colorSetKey.convert(isSystemDarkTheme: isSystemDarkTheme)
        self.fontSet = calendar.fontSetKey.convert()
        
        self.accnetDayPolicy = calendar.accnetDayPolicy
        self.showUnderLineOnEventDay = calendar.showUnderLineOnEventDay
        
        self.eventOnCalenarTextAdditionalSize = calendar.eventOnCalenarTextAdditionalSize
        self.eventOnCalendarIsBold = calendar.eventOnCalendarIsBold
        self.eventOnCalendarShowEventTagColor = calendar.eventOnCalendarShowEventTagColor
        
        self.eventTextAdditionalSize = calendar.eventTextAdditionalSize
        self.showHoliday = calendar.showHoliday
        self.showLunarCalendarDate = calendar.showLunarCalendarDate
        self.is24hourForm = calendar.is24hourForm
        
        self.hapticEffectOff = calendar.hapticEffectIsOn
        self.animationEffectOff = calendar.animationEffectIsOn
    }
}

// MARK: - combined property

extension ViewAppearance {
    
    public func accentCalendarDayColor(_ accent: AccentDays?) -> UIColor {
        switch accent {
        case .holiday:
            return self.accnetDayPolicy[.holiday] == true ? self.colorSet.holidayOrWeekEndWithAccent : self.colorSet.holidayText
        case .sunday:
            return self.accnetDayPolicy[.sunday] == true ? self.colorSet.holidayOrWeekEndWithAccent : self.colorSet.weekEndText
        case .saturday:
            return self.accnetDayPolicy[.saturday] == true ? self.colorSet.holidayOrWeekEndWithAccent : self.colorSet.weekEndText
        default:
            return self.colorSet.weekDayText
        }
    }
    
    public func eventTextFontOnCalendar() -> UIFont {
        let defaultSize: CGFloat = 10
        return UIFont.systemFont(
            ofSize: defaultSize + self.eventOnCalenarTextAdditionalSize,
            weight: self.eventOnCalendarIsBold ? .semibold : .regular
        )
    }
    
    public func eventTextFontOnList(isForemost: Bool = false) -> UIFont {
        let defaultSize: CGFloat = 14
        return UIFont.systemFont(
            ofSize: defaultSize + self.eventTextAdditionalSize,
            weight: isForemost ? .bold : .regular
        )
    }
    
    public func eventSubNormalTextFontOnList() -> UIFont {
        let defaultSize: CGFloat = 12
        return UIFont.systemFont(
            ofSize: defaultSize + self.eventTextAdditionalSize,
            weight: .regular
        )
    }
    
    @MainActor
    public func impactIfNeed(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) {
        guard self.hapticEffectOff else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    public func withAnimationIfNeed<R>(
        _ animation: Animation? = .default,
        _ body: () throws -> R
    ) rethrows -> R {
        guard animationEffectOff == false
        else {
            return try body()
        }
        return try withAnimation(animation, body)
    }
}

extension ViewAppearance {
    
    public var didUpdated: AnyPublisher<(EventTagColorSet, any FontSet, any ColorSet), Never> {
        return Publishers.CombineLatest3(
            self.$tagColors,
            self.$fontSet,
            self.$colorSet
        )
        .eraseToAnyPublisher()
    }
}

extension ColorSetKeys {
    
    public func convert(isSystemDarkTheme: Bool) -> any ColorSet {
        switch self {
        case .systemTheme where isSystemDarkTheme:
            return DefaultDarkColorSet()
        case .systemTheme:
            return DefaultLightColorSet()
        case .defaultLight:
            return DefaultLightColorSet()
        case .defaultDark:
            return DefaultDarkColorSet()
        }
    }
}

extension FontSetKeys {
    
    public func convert() -> any FontSet {
        switch self {
        case .systemDefault: return SystemDefaultFontSet()
        }
    }
}
