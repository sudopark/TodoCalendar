//
//  AppSettingLocalStorage.swift
//  Repository
//
//  Created by sudo.park on 4/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions


public struct AppSettingLocalStorage: Sendable {
    
    private let environmentStorage: any EnvironmentStorage
    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }
    
    private func keyWithUserId(_ userId: String?) -> (String) -> String {
        return { key in
            return userId.map { "\($0)::\(key)"} ?? key
        }
    }
}


// MARK: - appearance setting

extension AppSettingLocalStorage {
    
    private var holidayTagColorKey: String { "holiday_tag_color" }
    private var defaultTagColorKey: String { "default_tag_color" }
    private var colorSetKey: String { "color_set" }
    private var fontSetKey: String { "font_set" }
    
    // calendar
    private var accentDay_holidayKey: String { "accent_holiday" }
    private var accentDay_saturdayKey: String { "accent_saturday" }
    private var accentDay_sunday: String { "accent_sunday" }
    private var showUnderLineOnEventDayKey: String { "show_underline_eventday" }
    
    // event on calendar
    private var eventOnCalendarAdditionalFontSize: String { "event_on_calendar_additional_font_size" }
    private var boldTextEventOnCalendar: String { "bold_text_event_on_calendar" }
    private var notShowEventTagColorOnCalendar: String { "not_show_event_tag_color_on_calendar" }
    
    // event list
    private var eventAdditionaFontSize: String { "event_additiona_font_size" }
    private var showHolidayNameOnEventList: String { "show_holiday_name_on_eventList" }
    private var showLunarCalendarDate: String { "show_lunar_calendar_date" }
    private var is24HourForm: String { "is_24_hourForm" }
    private var hideUncompletedTodos: String { "hide_uncompleted_todos" }
    
    // widget
    private var widgetBackgroundKey: String { "widget_background" }
    
    // general
    private var hapticEffectIsOff: String { "haptic_effect_off" }
    private var animationEffectIsOn: String { "animation_effect_on" }
    
    func loadViewAppearance(for userId: String?) -> AppearanceSettings {
        
        let calendar = self.loadCalendarAppearanceSetting(for: userId)
        let defaultTagColors = self.loadDefaultTagColorSetting(for: userId)
        let widget = self.loadWidgetAppearanceSetting(for: userId)
        
        return AppearanceSettings(
           calendar: calendar,
           defaultTagColor: defaultTagColors,
           widget: widget
        )
    }
    
    func saveViewAppearance(_ newValue: AppearanceSettings, for userId: String?) {
        
        self.updateDefaultEventTagColors(newValue.defaultTagColor, for: userId)
        self.updateCalendarAppearanceSetting(newValue.calendar, for: userId)
        self.updateWidgetAppearanceSetting(newValue.widget, for: userId)
    }
    
    func loadCalendarAppearanceSetting(for userId: String?) -> CalendarAppearanceSettings {
        let colorSetRaw: String? = self.environmentStorage.load(colorSetKey)
        let fontSetRaw: String? = self.environmentStorage.load(fontSetKey)
        let colorSet = colorSetRaw.flatMap { ColorSetKeys(rawValue: $0) } ?? .systemTheme
        let fontSet = fontSetRaw.flatMap { FontSetKeys(rawValue: $0) } ?? .systemDefault
        
        var calendar = CalendarAppearanceSettings(
            colorSetKey: colorSet, fontSetKey: fontSet
        )
        
        // calendar
        let accentHoliday: Bool? = self.environmentStorage.load(accentDay_sunday)
        let accentSaturday: Bool? = self.environmentStorage.load(accentDay_saturdayKey)
        let accentSunday: Bool? = self.environmentStorage.load(accentDay_sunday)
        let isShowUnderline: Bool? = self.environmentStorage.load(showUnderLineOnEventDayKey)
        calendar = calendar
            |> \.accnetDayPolicy .~ [
                .sunday: accentSunday ?? false,
                .saturday: accentSaturday ?? false,
                .holiday: accentHoliday ?? false
            ]
            |> \.showUnderLineOnEventDay .~ (isShowUnderline ?? true)
        
        
        // event on calednar
        let eventOnCalendarAdditionalFont: Int =
        self.environmentStorage.load(eventOnCalendarAdditionalFontSize) ?? 0
        let eventOnCalendarBold: Bool = self.environmentStorage.load(boldTextEventOnCalendar) ?? false
        let eventOnCalendarShowColor: Bool = !(self.environmentStorage.load(notShowEventTagColorOnCalendar) ?? false)
        calendar = calendar
            |> \.eventOnCalenarTextAdditionalSize .~ CGFloat(eventOnCalendarAdditionalFont)
            |> \.eventOnCalendarIsBold .~ eventOnCalendarBold
            |> \.eventOnCalendarShowEventTagColor .~ eventOnCalendarShowColor
        
        // event list
        let eventFont: Int = self.environmentStorage.load(eventAdditionaFontSize) ?? 0
        let holiday: Bool = self.environmentStorage.load(showHolidayNameOnEventList) ?? false
        let lunar: Bool = self.environmentStorage.load(showLunarCalendarDate) ?? false
        let is24From: Bool = self.environmentStorage.load(is24HourForm) ?? true
        let hideUncompletedTodos: Bool = self.environmentStorage.load(hideUncompletedTodos) ?? false
        calendar = calendar
            |> \.eventTextAdditionalSize .~ CGFloat(eventFont)
            |> \.showHoliday .~ holiday
            |> \.showLunarCalendarDate .~ lunar
            |> \.is24hourForm .~ is24From
            |> \.showUncompletedTodos .~ !hideUncompletedTodos
        
        // general
        let hapticIsOn: Bool = !(self.environmentStorage.load(hapticEffectIsOff) ?? false)
        let animationIsOn: Bool = self.environmentStorage.load(animationEffectIsOn) ?? false
        calendar = calendar
            |> \.hapticEffectIsOn .~ hapticIsOn
            |> \.animationEffectIsOn .~ animationIsOn
        return calendar
    }
    
    func updateCalendarAppearanceSetting(_ newValue: CalendarAppearanceSettings, for userId: String?) {
        self.environmentStorage.update(
            self.colorSetKey, newValue.colorSetKey.rawValue
        )
        self.environmentStorage.update(
            self.fontSetKey, newValue.fontSetKey.rawValue
        )
        
        // calendar
        self.environmentStorage.update(
            self.accentDay_sunday, newValue.accnetDayPolicy[.sunday] ?? false
        )
        self.environmentStorage.update(
            self.accentDay_saturdayKey, newValue.accnetDayPolicy[.saturday] ?? false
        )
        self.environmentStorage.update(
            self.accentDay_holidayKey, newValue.accnetDayPolicy[.holiday] ?? false
        )
        self.environmentStorage.update(
            showUnderLineOnEventDayKey, newValue.showUnderLineOnEventDay
        )
        
        // event on calendar
        self.environmentStorage.update(
            eventOnCalendarAdditionalFontSize, Int(newValue.eventOnCalenarTextAdditionalSize)
        )
        self.environmentStorage.update(
            boldTextEventOnCalendar, newValue.eventOnCalendarIsBold
        )
        self.environmentStorage.update(
            notShowEventTagColorOnCalendar, !newValue.eventOnCalendarShowEventTagColor
        )
        
        // event list
        self.environmentStorage.update(
            eventAdditionaFontSize, Int(newValue.eventTextAdditionalSize)
        )
        self.environmentStorage.update(
            showHolidayNameOnEventList, newValue.showHoliday
        )
        self.environmentStorage.update(
            showLunarCalendarDate, newValue.showLunarCalendarDate
        )
        self.environmentStorage.update(
            is24HourForm, newValue.is24hourForm
        )
        self.environmentStorage.update(
            hideUncompletedTodos, !newValue.showUncompletedTodos
        )
        
        // general
        self.environmentStorage.update(hapticEffectIsOff, !newValue.hapticEffectIsOn)
        self.environmentStorage.update(animationEffectIsOn, newValue.animationEffectIsOn)
    }
    
    func loadDefaultTagColorSetting(for userId: String?) -> DefaultEventTagColorSetting {
        let holidayTagColor: String? = self.environmentStorage.load(
            holidayTagColorKey |> self.keyWithUserId(userId)
        )
        let defaultTagColor: String? = self.environmentStorage.load(
            defaultTagColorKey |> self.keyWithUserId(userId)
        )
        let defSetting = DefaultEventTagColorSetting.default
        return DefaultEventTagColorSetting(
            holiday: holidayTagColor ?? defSetting.holiday,
            default: defaultTagColor ?? defSetting.default
        )
    }
    
    func updateDefaultEventTagColors(_ newValue: DefaultEventTagColorSetting, for userId: String?) {
        self.environmentStorage.update(
            self.holidayTagColorKey |> self.keyWithUserId(userId),
            newValue.holiday
        )
        self.environmentStorage.update(
            self.defaultTagColorKey |> self.keyWithUserId(userId),
            newValue.default
        )
    }
    
    func loadWidgetAppearanceSetting(for userId: String?) -> WidgetAppearanceSettings {
        let background: WidgetAppearanceSettings.Background? = self.environmentStorage.load(widgetBackgroundKey)
        return WidgetAppearanceSettings()
            |> \.background .~ (background ?? .system)
    }
    
    func updateWidgetAppearanceSetting(
        _ newValue: WidgetAppearanceSettings, for userId: String?
    ) {
        self.environmentStorage.update(
            self.widgetBackgroundKey,
            newValue.background
        )
    }
}

// MARK: - event setting

extension AppSettingLocalStorage {
    
    // event setting
    private var defaultNewEventTagId: String { "default_new_event_tagId" }
    private var defaultNewEventPeriod: String { "default_new_event_period" }
    private var defaultMapApp: String { "default_map_app" }
    
    func loadEventSetting(for userId: String?) -> EventSettings {
        let tagIdRaw: String? = self.environmentStorage.load(defaultNewEventTagId)
        let tagId: EventTagId = tagIdRaw.map { value in
            switch value {
            case "holiday": return EventTagId.holiday
            case "default": return EventTagId.default
            default: return EventTagId.custom(value)
            }
        } ?? .default
        
        let periodRaw: String? = self.environmentStorage.load(defaultNewEventPeriod)
        let period: EventSettings.DefaultNewEventPeriod = periodRaw.flatMap {
            EventSettings.DefaultNewEventPeriod(rawValue: $0)
        } ?? .minute0
        
        let defaultMapApp: String? = self.environmentStorage.load(defaultMapApp)
        
        return EventSettings()
            |> \.defaultNewEventTagId .~ tagId
            |> \.defaultNewEventPeriod .~ period
            |> \.defaultMapApp .~ defaultMapApp.flatMap { SupportMapApps(rawValue: $0) }
    }
    
    func saveEventSetting(_ newValue: EventSettings, for userId: String?) {
        self.environmentStorage.update(
            defaultNewEventTagId,
            newValue.defaultNewEventTagId.rawValue
        )
        self.environmentStorage.update(
            defaultNewEventPeriod,
            newValue.defaultNewEventPeriod.rawValue
        )
        if let app = newValue.defaultMapApp {
            self.environmentStorage.update(defaultMapApp, app.rawValue)
        } else {
            self.environmentStorage.remove(defaultMapApp)
        }
    }
}


private extension EventTagId {
    
    var rawValue: String {
        switch self {
        case .holiday: return "holiday"
        case .default: return "default"
        case .custom(let value): return value
        case .externalCalendar(let serviceId, let id): return "external::\(serviceId)::\(id)"
        }
    }
}
