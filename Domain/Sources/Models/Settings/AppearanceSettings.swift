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
    case defaultLight
}

public enum FontSetKeys: String, Sendable {
    case systemDefault
}

public struct EventTagColorSetting: Equatable {
    public let holiday: String
    public let `default`: String
    
    public init(holiday: String, `default`: String) {
        self.holiday = holiday
        self.default = `default`
    }
}

public enum AccentDays: Sendable {
    case holiday
    case saturday
    case sunday
}

public struct AppearanceSettings: Equatable {
    
    public let tagColorSetting: EventTagColorSetting
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
    
    // general
    public var hapticEffectIsOn: Bool = false
    public var animationEffectIsOn: Bool = false
    
    public init(
        tagColorSetting: EventTagColorSetting,
        colorSetKey: ColorSetKeys,
        fontSetKey: FontSetKeys
    ) {
        self.tagColorSetting = tagColorSetting
        self.colorSetKey = colorSetKey
        self.fontSetKey = fontSetKey
    }
    
    public func update(_ params: EditAppearanceSettingParams) -> AppearanceSettings {
        let newTagColorSetting = EventTagColorSetting(
            holiday: params.newTagColorSetting?.newHolidayTagColor ?? self.tagColorSetting.holiday,
            default: params.newTagColorSetting?.newDefaultTagColor ?? self.tagColorSetting.default
        )
        let newSetting = AppearanceSettings(
            tagColorSetting: newTagColorSetting,
            colorSetKey: params.newColorSetKey ?? self.colorSetKey,
            fontSetKey: params.newFontSetKcy ?? self.fontSetKey
        )
        return newSetting
            |> \.accnetDayPolicy .~ (params.accnetDayPolicy ?? self.accnetDayPolicy)
            |> \.showUnderLineOnEventDay .~ (params.showUnderLineOnEventDay ?? self.showUnderLineOnEventDay)
            |> \.eventOnCalenarTextAdditionalSize .~ (params.eventOnCalenarTextAdditionalSize ?? self.eventOnCalenarTextAdditionalSize)
            |> \.eventOnCalendarIsBold .~ (params.eventOnCalendarIsBold ?? self.eventOnCalendarIsBold)
            |> \.eventOnCalendarShowEventTagColor .~ (params.eventOnCalendarShowEventTagColor ?? self.eventOnCalendarShowEventTagColor)
            |> \.eventTextAdditionalSize .~ (params.eventTextAdditionalSize ?? self.eventTextAdditionalSize)
            |> \.showHoliday .~ (params.showHoliday ?? self.showHoliday)
            |> \.showLunarCalendarDate .~ (params.showLunarCalendarDate ?? self.showLunarCalendarDate)
            |> \.is24hourForm .~ (params.is24hourForm ?? self.is24hourForm)
            |> \.hapticEffectIsOn .~ (params.hapticEffectIsOn ?? self.hapticEffectIsOn)
            |> \.animationEffectIsOn .~ (params.animationEffectIsOn ?? self.animationEffectIsOn)
    }
}

// MARK: - edit params

public struct EditAppearanceSettingParams {
    
    public struct EditEventTagColorParams {
        public var newHolidayTagColor: String?
        public var newDefaultTagColor: String?
        public init() { }
    }
    
    public var newTagColorSetting: EditEventTagColorParams?
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
        return self.newTagColorSetting?.newHolidayTagColor != nil
            || self.newTagColorSetting?.newDefaultTagColor != nil
            || self.newColorSetKey != nil
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
    }
    
    private var isValidGeneralValues: Bool {
        return self.hapticEffectIsOn != nil
            || self.animationEffectIsOn != nil
    }
}
