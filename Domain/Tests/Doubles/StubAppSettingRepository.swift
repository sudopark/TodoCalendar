//
//  StubAppSettingRepository.swift
//  DomainTests
//
//  Created by sudo.park on 2023/10/08.
//

import Foundation
import Prelude
import Optics

@testable import Domain


class StubAppSettingRepository: AppSettingRepository, @unchecked Sendable {
    
    var stubAppearanceSetting: AppearanceSettings?
    func loadSavedViewAppearance() -> AppearanceSettings {
        if let setting = self.stubAppearanceSetting {
            return setting
        }
        return .init(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "holiday", default: "default")
        )
    }
    
    func refreshAppearanceSetting() async throws -> AppearanceSettings {
        return self.loadSavedViewAppearance()
    }
    
    func changeCalendarAppearanceSetting(
        _ params: EditCalendarAppearanceSettingParams
    ) throws -> CalendarAppearanceSettings {
        let old = self.loadSavedViewAppearance()
        let new = old |> \.calendar .~ old.calendar.update(params)
        self.stubAppearanceSetting = new
        return new.calendar
    }
    
    func changeDefaultEventTagColor(
        _ params: EditDefaultEventTagColorParams
    ) async throws -> DefaultEventTagColorSetting {
        let old = self.loadSavedViewAppearance()
        let new = old |> \.defaultTagColor .~ old.defaultTagColor.update(params)
        self.stubAppearanceSetting = new
        return new.defaultTagColor
    }
    
    var stubEvnetSetting: EventSettings?
    func loadEventSetting() -> EventSettings {
        if let setting = self.stubEvnetSetting {
            return setting
        }
        return EventSettings()
    }
    
    func changeEventSetting(_ params: EditEventSettingsParams) -> EventSettings {
        let old = self.loadEventSetting()
        let newSetting = old
        |> \.defaultNewEventTagId .~ (params.defaultNewEventTagId ?? old.defaultNewEventTagId)
        |> \.defaultNewEventPeriod .~ (params.defaultNewEventPeriod ?? old.defaultNewEventPeriod)
        return newSetting
    }
}
