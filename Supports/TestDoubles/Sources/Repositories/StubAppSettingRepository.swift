//
//  StubAppSettingRepository.swift
//  TestDoubles
//
//  Created by sudo.park on 6/2/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain


open class StubAppSettingRepository: AppSettingRepository, @unchecked Sendable {
    
    public init() { }
    
    public var stubAppearanceSetting: AppearanceSettings?
    open func loadSavedViewAppearance() -> AppearanceSettings {
        if let setting = self.stubAppearanceSetting {
            return setting
        }
        return .init(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "holiday", default: "default")
        )
    }
    
    open func refreshAppearanceSetting() async throws -> AppearanceSettings {
        return self.loadSavedViewAppearance()
    }
    
    open func changeCalendarAppearanceSetting(
        _ params: EditCalendarAppearanceSettingParams
    ) throws -> CalendarAppearanceSettings {
        let old = self.loadSavedViewAppearance()
        let new = old |> \.calendar .~ old.calendar.update(params)
        self.stubAppearanceSetting = new
        return new.calendar
    }
    
    open func changeDefaultEventTagColor(
        _ params: EditDefaultEventTagColorParams
    ) async throws -> DefaultEventTagColorSetting {
        let old = self.loadSavedViewAppearance()
        let new = old |> \.defaultTagColor .~ old.defaultTagColor.update(params)
        self.stubAppearanceSetting = new
        return new.defaultTagColor
    }
    
    public var stubEvnetSetting: EventSettings?
    open func loadEventSetting() -> EventSettings {
        if let setting = self.stubEvnetSetting {
            return setting
        }
        return EventSettings()
    }
    
    open func changeEventSetting(_ params: EditEventSettingsParams) -> EventSettings {
        let old = self.loadEventSetting()
        let newSetting = old
        |> \.defaultNewEventTagId .~ (params.defaultNewEventTagId ?? old.defaultNewEventTagId)
        |> \.defaultNewEventPeriod .~ (params.defaultNewEventPeriod ?? old.defaultNewEventPeriod)
        return newSetting
    }
    
    open func loadWidgetAppearanceSetting() -> WidgetAppearanceSettings {
        return self.loadSavedViewAppearance().widget
    }
    
    open func updateWidgetAppearance(_ params: EditWidgetAppearanceSettingParams) -> WidgetAppearanceSettings {
        let old = self.loadWidgetAppearanceSetting()
        let new = old.update(params)
        let appearance = self.loadSavedViewAppearance() |> \.widget .~ new
        stubAppearanceSetting = appearance
        return new
    }
}
