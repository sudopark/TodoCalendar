//
//  AppearanceSettings.swift
//  Domain
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation
import Prelude
import Optics

public enum ColorSetKeys: String, Sendable {
    case systemTheme
    case defaultLight
    case defaultDark
}

public enum FontSetKeys: String, Sendable {
    case systemDefault
}

public struct DefaultEventTagColorSetting: Equatable, Sendable {
    public let holiday: String
    public let `default`: String
    
    public init(holiday: String, `default`: String) {
        self.holiday = holiday
        self.default = `default`
    }
    
    public func update(_ params: EditDefaultEventTagColorParams) -> DefaultEventTagColorSetting {
        return DefaultEventTagColorSetting(
            holiday: params.newHolidayTagColor ?? self.holiday,
            default: params.newDefaultTagColor ?? self.default
        )
    }
}

public enum AccentDays: Sendable {
    case holiday
    case saturday
    case sunday
}

public struct CalendarAppearanceSettings: Equatable, Sendable {
    
    public let colorSetKey: ColorSetKeys
    public let fontSetKey: FontSetKeys
    
    // calendar
    public var accnetDayPolicy: [AccentDays: Bool] = [:]
    public var showUnderLineOnEventDay: Bool = false
    
    // event on calendar
    public var eventOnCalenarTextAdditionalSize: CGFloat = 0
    public var eventOnCalendarIsBold: Bool = false
    public var eventOnCalendarShowEventTagColor: Bool = true
    
    // event list
    public var eventTextAdditionalSize: CGFloat = 0
    public var showHoliday: Bool = false
    public var showLunarCalendarDate: Bool = false
    public var is24hourForm: Bool = false
    public var showUncompletedTodos: Bool = true
    
    // general
    public var hapticEffectIsOn: Bool = false
    public var animationEffectIsOn: Bool = false
    
    public init(
        colorSetKey: ColorSetKeys,
        fontSetKey: FontSetKeys
    ) {
        self.colorSetKey = colorSetKey
        self.fontSetKey = fontSetKey
    }
    
    public func update(_ params: EditCalendarAppearanceSettingParams) -> CalendarAppearanceSettings {

        var newSetting = CalendarAppearanceSettings(
            colorSetKey: params.newColorSetKey ?? self.colorSetKey,
            fontSetKey: params.newFontSetKcy ?? self.fontSetKey
        )
        newSetting.accnetDayPolicy = (params.accnetDayPolicy ?? self.accnetDayPolicy)
        newSetting.showUnderLineOnEventDay = (params.showUnderLineOnEventDay ?? self.showUnderLineOnEventDay)
        newSetting.eventOnCalenarTextAdditionalSize = (params.eventOnCalenarTextAdditionalSize ?? self.eventOnCalenarTextAdditionalSize)
        newSetting.eventOnCalendarIsBold = (params.eventOnCalendarIsBold ?? self.eventOnCalendarIsBold)
        newSetting.eventOnCalendarShowEventTagColor = (params.eventOnCalendarShowEventTagColor ?? self.eventOnCalendarShowEventTagColor)
        newSetting.eventTextAdditionalSize = (params.eventTextAdditionalSize ?? self.eventTextAdditionalSize)
        newSetting.showHoliday = (params.showHoliday ?? self.showHoliday)
        newSetting.showLunarCalendarDate = (params.showLunarCalendarDate ?? self.showLunarCalendarDate)
        newSetting.is24hourForm = (params.is24hourForm ?? self.is24hourForm)
        newSetting.showUncompletedTodos = (params.showUncompletedTodos ?? self.showUncompletedTodos)
        newSetting.hapticEffectIsOn = (params.hapticEffectIsOn ?? self.hapticEffectIsOn)
        newSetting.animationEffectIsOn = (params.animationEffectIsOn ?? self.animationEffectIsOn)
        return newSetting
    }
}

public struct AppearanceSettings: Sendable {
    
    public var calendar: CalendarAppearanceSettings
    public var defaultTagColor: DefaultEventTagColorSetting
    
    public init(
        calendar: CalendarAppearanceSettings,
        defaultTagColor: DefaultEventTagColorSetting
    ) {
        self.calendar = calendar
        self.defaultTagColor = defaultTagColor
    }
}

// MARK: - edit params

public struct EditDefaultEventTagColorParams {
    public var newHolidayTagColor: String?
    public var newDefaultTagColor: String?
    public init() { }
    
    public var isValid: Bool {
        return self.newHolidayTagColor != nil
            || self.newDefaultTagColor != nil
    }
}

public struct EditCalendarAppearanceSettingParams {
    
    public var newColorSetKey: ColorSetKeys?
    public var newFontSetKcy: FontSetKeys?
    
    public var accnetDayPolicy: [AccentDays: Bool]?
    public var showUnderLineOnEventDay: Bool?
    
    // event on calendar
    public var eventOnCalenarTextAdditionalSize: CGFloat?
    public var eventOnCalendarIsBold: Bool?
    public var eventOnCalendarShowEventTagColor: Bool?
    
    // event list
    public var eventTextAdditionalSize: CGFloat?
    public var showHoliday: Bool?
    public var showLunarCalendarDate: Bool?
    public var is24hourForm: Bool?
    public var showUncompletedTodos: Bool?
    
    // general
    public var hapticEffectIsOn: Bool?
    public var animationEffectIsOn: Bool?
    
    public init() { }
    
    public var isValid: Bool {
        
        return isValidBaseValues 
            || isValidCalendarValues
            || isValidEventOnCalendarValues
            || isValidEventListValues
            || isValidGeneralValues
    }
    
    private var isValidBaseValues: Bool {
        return self.newColorSetKey != nil
            || self.newFontSetKcy != nil
    }
    
    private var isValidCalendarValues: Bool {
        return self.accnetDayPolicy != nil
            || self.showUnderLineOnEventDay != nil
    }
    
    private var isValidEventOnCalendarValues: Bool {
        return self.eventOnCalenarTextAdditionalSize != nil
            || self.eventOnCalendarIsBold != nil
            || self.eventOnCalendarShowEventTagColor != nil
    }
    
    private var isValidEventListValues: Bool {
        return self.eventTextAdditionalSize != nil
            || self.showHoliday != nil
            || self.showLunarCalendarDate != nil
            || self.is24hourForm != nil
            || self.showUncompletedTodos != nil
    }
    
    private var isValidGeneralValues: Bool {
        return self.hapticEffectIsOn != nil
            || self.animationEffectIsOn != nil
    }
}
