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
    
    private var holidayTagColorKey: String { "holiday_tag_color" }
    private var defaultTagColorKey: String { "default_tag_color" }
    private var colorSetKey: String { "color_set" }
    private var fontSetKey: String { "font_set" }
    private var accentDay_holidayKey: String { "accent_holiday" }
    private var accentDay_saturdayKey: String { "accent_saturday" }
    private var accentDay_sunday: String { "accent_sunday" }
    private var showUnderLineOnEventDayKey: String { "show_underline_eventday" }
}


extension AppSettingRepositoryImple {
    
    public func loadSavedViewAppearance() -> AppearanceSettings {
        let holidayTagColor: String? = self.environmentStorage.load(holidayTagColorKey)
        let defaultTagColor: String? = self.environmentStorage.load(defaultTagColorKey)
        let colorSetRaw: String? = self.environmentStorage.load(colorSetKey)
        let fontSetRaw: String? = self.environmentStorage.load(fontSetKey)
        let colorSet = colorSetRaw.flatMap { ColorSetKeys(rawValue: $0) } ?? .defaultLight
        let fontSet = fontSetRaw.flatMap { FontSetKeys(rawValue: $0) } ?? .systemDefault
        
        let accentHoliday: Bool? = self.environmentStorage.load(accentDay_sunday)
        let accentSaturday: Bool? = self.environmentStorage.load(accentDay_saturdayKey)
        let accentSunday: Bool? = self.environmentStorage.load(accentDay_sunday)
        let isShowUnderline: Bool? = self.environmentStorage.load(showUnderLineOnEventDayKey)
        
        return AppearanceSettings(
            tagColorSetting: .init(
                holiday: holidayTagColor ?? "#D6236A",
                default: defaultTagColor ?? "#088CDA"
            ),
            colorSetKey: colorSet,
            fontSetKey: fontSet,
            accnetDayPolicy: [
                .holiday: accentHoliday ?? false,
                .saturday: accentSaturday ?? false,
                .sunday: accentSunday ?? false
            ],
            showUnderLineOnEventDay: isShowUnderline ?? true
        )
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
    }
    
    public func changeAppearanceSetting(_ params: EditAppearanceSettingParams) -> AppearanceSettings {
        let setting = self.loadSavedViewAppearance()
        let newTagColorSetting = EventTagColorSetting(
            holiday: params.newTagColorSetting?.newHolidayTagColor ?? setting.tagColorSetting.holiday,
            default: params.newTagColorSetting?.newDefaultTagColor ?? setting.tagColorSetting.default
        )
        let newSetting = AppearanceSettings(
            tagColorSetting: newTagColorSetting,
            colorSetKey: params.newColorSetKey ?? setting.colorSetKey,
            fontSetKey: params.newFontSetKcy ?? setting.fontSetKey,
            accnetDayPolicy: params.newAccentDays ?? setting.accnetDayPolicy,
            showUnderLineOnEventDay: params.newShowUnderLineOnEventDay ?? setting.showUnderLineOnEventDay
        )
        
        self.saveViewAppearanceSetting(newSetting)
        
        return newSetting
    }
}
