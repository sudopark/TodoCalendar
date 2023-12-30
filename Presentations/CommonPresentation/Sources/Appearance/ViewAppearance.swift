//
//  ViewAppearance.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/05.
//

import UIKit
import Combine
import Domain


public class ViewAppearance: ObservableObject {
    
    @Published public var tagColors: EventTagColorSet
    @Published public var colorSet: any ColorSet
    @Published public var fontSet: any FontSet
    
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
    @Published public var dimOnPastEvent: Bool
    
    // general
    @Published public var hapticEffectOff: Bool
    @Published public var animationEffectOff: Bool
    
    public init(setting: AppearanceSettings) {
        
        self.tagColors = .init(
            holiday: UIColor.from(hex: setting.tagColorSetting.holiday) ?? .clear,
            defaultColor: UIColor.from(hex: setting.tagColorSetting.default) ?? .clear
        )
        self.colorSet = setting.colorSetKey.convert()
        self.fontSet = setting.fontSetKey.convert()
        
        self.accnetDayPolicy = setting.accnetDayPolicy
        self.showUnderLineOnEventDay = setting.showUnderLineOnEventDay
        
        self.eventOnCalenarTextAdditionalSize = setting.eventOnCalenarTextAdditionalSize
        self.eventOnCalendarIsBold = setting.eventOnCalendarIsBold
        self.eventOnCalendarShowEventTagColor = setting.eventOnCalendarShowEventTagColor
        
        self.eventTextAdditionalSize = setting.eventTextAdditionalSize
        self.showHoliday = setting.showHoliday
        self.showLunarCalendarDate = setting.showLunarCalendarDate
        self.is24hourForm = setting.is24hourForm
        self.dimOnPastEvent = setting.dimOnPastEvent
        
        self.hapticEffectOff = setting.hapticEffectIsOn
        self.animationEffectOff = setting.animationEffectIsOn
    }
}

// MARK: - combined property

extension ViewAppearance {
    
    public func accentCalendarDayColor(_ accent: AccentDays?) -> UIColor {
        switch accent {
        case .holiday:
            return self.accnetDayPolicy[.holiday] == true ? self.colorSet.calendarAccentColor : self.colorSet.holidayText
        case .sunday:
            return self.accnetDayPolicy[.sunday] == true ? self.colorSet.calendarAccentColor : self.colorSet.holidayText
        case .saturday:
            return self.accnetDayPolicy[.saturday] == true ? self.colorSet.calendarAccentColor : self.colorSet.holidayText
        default:
            return self.colorSet.weekDayText
        }
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
    
    public func convert() -> any ColorSet {
        switch self {
        case .defaultLight: return DefaultLightColorSet()
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
