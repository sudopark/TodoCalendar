//
//  StubUISettingUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/10/09.
//

import Foundation
import Domain
import Prelude
import Optics

open class StubUISettingUsecase: UISettingUsecase, @unchecked Sendable {
    
    public init() { }
    
    public var stubAppearanceSetting: AppearanceSettings?
    open func loadAppearanceSetting() -> AppearanceSettings {
        if let setting = self.stubAppearanceSetting {
            return setting
        }
        return AppearanceSettings(
            tagColorSetting: .init(holiday: "holiday", default: "default"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault,
            accnetDayPolicy: [.sunday: true, .saturday: false, .holiday: false],
            showUnderLineOnEventDay: true,
            eventOnCalendar: .init(),
            eventList: .init()
        )
        |> \.hapticEffectOff .~ false
        |> \.animationEffectOff .~ false
    }
    
    public var didChangeAppearanceSetting: AppearanceSettings?
    open func changeAppearanceSetting(_ params: EditAppearanceSettingParams) throws -> AppearanceSettings {
        let old = self.loadAppearanceSetting()
        let newSetting = AppearanceSettings(
            tagColorSetting: .init(
                holiday: params.newTagColorSetting?.newHolidayTagColor ?? old.tagColorSetting.holiday,
                default: params.newTagColorSetting?.newDefaultTagColor ?? old.tagColorSetting.default),
            colorSetKey: params.newColorSetKey ?? old.colorSetKey,
            fontSetKey: params.newFontSetKcy ?? old.fontSetKey,
            accnetDayPolicy: params.newAccentDays ?? old.accnetDayPolicy,
            showUnderLineOnEventDay: params.newShowUnderLineOnEventDay ?? old.showUnderLineOnEventDay,
            eventOnCalendar: params.eventOnCalendar ?? old.eventOnCalendar,
            eventList: params.eventList ?? old.eventList
        )
        |> \.hapticEffectOff .~ (params.hapticEffectOff ?? old.hapticEffectOff)
        |> \.animationEffectOff .~ (params.animationEffectOff ?? old.animationEffectOff)
        self.didChangeAppearanceSetting = newSetting
        self.stubAppearanceSetting = newSetting
        return newSetting
    }
}