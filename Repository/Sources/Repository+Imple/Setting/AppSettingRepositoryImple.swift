//
//  AppSettingRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation
import Prelude
import Optics
import Domain


public final class AppSettingRepositoryImple: AppSettingRepository {
    
    private let environmentStorage: any EnvironmentStorage
    
    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }
}


// MARK: - appearance setting

extension AppSettingRepositoryImple {
    
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
    private var showEventTagColorOnCalendar: String { "show_event_tag_color_on_calendar" }
    
    // event list
    private var eventAdditionaFontSize: String { "event_additiona_font_size" }
    private var showHolidayNameOnEventList: String { "show_holiday_name_on_eventList" }
    private var showLunarCalendarDate: String { "show_lunar_calendar_date" }
    private var is24HourForm: String { "is_24_hourForm" }
    
    // general
    private var hapticEffectIsOn: String { "haptic_effect_on" }
    private var animationEffectIsOn: String { "animation_effect_on" }
    
    public func loadSavedViewAppearance() -> AppearanceSettings {
        let holidayTagColor: String? = self.environmentStorage.load(holidayTagColorKey)
        let defaultTagColor: String? = self.environmentStorage.load(defaultTagColorKey)
        let colorSetRaw: String? = self.environmentStorage.load(colorSetKey)
        let fontSetRaw: String? = self.environmentStorage.load(fontSetKey)
        let colorSet = colorSetRaw.flatMap { ColorSetKeys(rawValue: $0) } ?? .defaultLight
        let fontSet = fontSetRaw.flatMap { FontSetKeys(rawValue: $0) } ?? .systemDefault
        
        var setting = AppearanceSettings(
            tagColorSetting: .init(
                holiday: holidayTagColor ?? "#D6236A",
                default: defaultTagColor ?? "#088CDA"
            ),
            colorSetKey: colorSet,
            fontSetKey: fontSet
        )
        
        // calendar
        let accentHoliday: Bool? = self.environmentStorage.load(accentDay_sunday)
        let accentSaturday: Bool? = self.environmentStorage.load(accentDay_saturdayKey)
        let accentSunday: Bool? = self.environmentStorage.load(accentDay_sunday)
        let isShowUnderline: Bool? = self.environmentStorage.load(showUnderLineOnEventDayKey)
        setting = setting
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
        let eventOnCalendarShowColor: Bool = self.environmentStorage.load(showEventTagColorOnCalendar) ?? true
        setting = setting
            |> \.eventOnCalenarTextAdditionalSize .~ CGFloat(eventOnCalendarAdditionalFont)
            |> \.eventOnCalendarIsBold .~ eventOnCalendarBold
            |> \.eventOnCalendarShowEventTagColor .~ eventOnCalendarShowColor
        
        // event list
        let eventFont: Int = self.environmentStorage.load(eventAdditionaFontSize) ?? 0
        let holiday: Bool = self.environmentStorage.load(showHolidayNameOnEventList) ?? false
        let lunar: Bool = self.environmentStorage.load(showLunarCalendarDate) ?? false
        let is24From: Bool = self.environmentStorage.load(is24HourForm) ?? true
        setting = setting
            |> \.eventTextAdditionalSize .~ CGFloat(eventFont)
            |> \.showHoliday .~ holiday
            |> \.showLunarCalendarDate .~ lunar
            |> \.is24hourForm .~ is24From
        
        // general
        let hapticIsOn: Bool = self.environmentStorage.load(hapticEffectIsOn) ?? true
        let animationIsOn: Bool = self.environmentStorage.load(animationEffectIsOn) ?? false
        
        return setting
            |> \.hapticEffectIsOn .~ hapticIsOn
            |> \.animationEffectIsOn .~ animationIsOn
    }
    
    public func saveViewAppearanceSetting(_ newValue: AppearanceSettings) {
        self.environmentStorage.update(
            self.holidayTagColorKey, newValue.tagColorSetting.holiday
        )
        self.environmentStorage.update(
            self.defaultTagColorKey, newValue.tagColorSetting.default
        )
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
            showEventTagColorOnCalendar, newValue.eventOnCalendarShowEventTagColor
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
        
        // general
        self.environmentStorage.update(hapticEffectIsOn, newValue.hapticEffectIsOn)
        self.environmentStorage.update(animationEffectIsOn, newValue.animationEffectIsOn)
    }
    
    public func changeAppearanceSetting(_ params: EditAppearanceSettingParams) -> AppearanceSettings {
        let setting = self.loadSavedViewAppearance()
        
        let newSetting = setting.update(params)
        
        self.saveViewAppearanceSetting(newSetting)
        
        return newSetting
    }
}


// MARK: - event setting

extension AppSettingRepositoryImple {
    
    // event setting
    private var defaultNewEventTagId: String { "default_new_event_tagId" }
    private var defaultNewEventPeriod: String { "default_new_event_period" }
    
    public func loadEventSetting() -> EventSettings {
        let tagIdRaw: String? = self.environmentStorage.load(defaultNewEventTagId)
        let tagId: AllEventTagId = tagIdRaw.map { value in
            switch value {
            case "holiday": return AllEventTagId.holiday
            case "default": return AllEventTagId.default
            default: return AllEventTagId.custom(value)
            }
        } ?? .default
        
        let periodRaw: String? = self.environmentStorage.load(defaultNewEventPeriod)
        let period: EventSettings.DefaultNewEventPeriod = periodRaw.flatMap {
            EventSettings.DefaultNewEventPeriod(rawValue: $0)
        } ?? .hour1
        
        return EventSettings()
            |> \.defaultNewEventTagId .~ tagId
            |> \.defaultNewEventPeriod .~ period
    }
    
    public func changeEventSetting(_ params: EditEventSettingsParams) -> EventSettings {
        let old = self.loadEventSetting()
        let newSetting = old
            |> \.defaultNewEventTagId .~ (params.defaultNewEventTagId ?? old.defaultNewEventTagId)
            |> \.defaultNewEventPeriod .~ (params.defaultNewEventPeriod ??  old.defaultNewEventPeriod)
        
        self.environmentStorage.update(defaultNewEventTagId, newSetting.defaultNewEventTagId.rawValue)
        self.environmentStorage.update(defaultNewEventPeriod, newSetting.defaultNewEventPeriod.rawValue)
        return newSetting
    }
}

private extension AllEventTagId {
    
    var rawValue: String {
        switch self {
        case .holiday: return "holiday"
        case .default: return "default"
        case .custom(let value): return value
        }
    }
}
