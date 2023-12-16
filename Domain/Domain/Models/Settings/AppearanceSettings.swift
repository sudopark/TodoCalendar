//
//  AppearanceSettings.swift
//  Domain
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation

public enum ColorSetKeys: String, Sendable {
    case defaultLight
}

public enum FontSetKeys: String, Sendable {
    case systemDefault
}

public struct EventTagColorSetting {
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

public struct EventOnCalendarSetting: Sendable, Equatable {
    
    public var textAdditionalSize: CGFloat = 0
    public var bold: Bool = false
    public var showEventTagColor: Bool = true
    
    public init() { }
}

public struct EventListSetting: Sendable, Equatable {
    
    public var textAdditionalSize: CGFloat = 0
    public var showHoliday: Bool = false
    public var showLunarCalendarDate: Bool = false
    public var is24hourForm: Bool = false
    public var dimOnPastEvent: Bool = false
    
    public init() { }
}

public struct AppearanceSettings {
    
    public let tagColorSetting: EventTagColorSetting
    public let colorSetKey: ColorSetKeys
    public let fontSetKey: FontSetKeys
    public let accnetDayPolicy: [AccentDays: Bool]
    public let showUnderLineOnEventDay: Bool
    
    public let eventOnCalendar: EventOnCalendarSetting
    public let eventList: EventListSetting
    
    public init(
        tagColorSetting: EventTagColorSetting,
        colorSetKey: ColorSetKeys,
        fontSetKey: FontSetKeys,
        accnetDayPolicy: [AccentDays: Bool],
        showUnderLineOnEventDay: Bool,
        eventOnCalendar: EventOnCalendarSetting,
        eventList: EventListSetting
    ) {
        self.tagColorSetting = tagColorSetting
        self.colorSetKey = colorSetKey
        self.fontSetKey = fontSetKey
        self.accnetDayPolicy = accnetDayPolicy
        self.showUnderLineOnEventDay = showUnderLineOnEventDay
        self.eventOnCalendar = eventOnCalendar
        self.eventList = eventList
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
    public var newAccentDays: [AccentDays: Bool]?
    public var newShowUnderLineOnEventDay: Bool?
    public var eventOnCalendar: EventOnCalendarSetting?
    public var eventList: EventListSetting?
    
    public init() { }
    
    public var isValid: Bool {
        return self.newTagColorSetting?.newHolidayTagColor != nil
            || self.newTagColorSetting?.newDefaultTagColor != nil
            || self.newColorSetKey != nil
            || self.newFontSetKcy != nil
            || self.newAccentDays != nil
            || self.newShowUnderLineOnEventDay != nil
            || self.eventOnCalendar != nil
            || self.eventList != nil
    }
}
