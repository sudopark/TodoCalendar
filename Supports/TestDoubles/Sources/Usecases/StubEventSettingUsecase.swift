//
//  StubEventSettingUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Prelude
import Optics

open class StubEventSettingUsecase: EventSettingUsecase, @unchecked Sendable {
    
    public init() {}
    private let settingSubject = CurrentValueSubject<EventSettings?, Never>(nil)
    
    public var stubSetting: EventSettings?
    open func loadEventSetting() -> EventSettings {
        if let setting = self.stubSetting {
            self.settingSubject.send(setting)
            return setting
        }
        
        let setting = EventSettings()
        self.settingSubject.send(setting)
        return setting
    }
    
    public func refreshEventSetting() async throws -> EventSettings {
        return self.loadEventSetting()
    }
    
    open func changeEventSetting(_ params: EditEventSettingsParams) throws -> EventSettings {
        let old = self.loadEventSetting()
        let new = old
            |> \.defaultNewEventTagId .~ (params.defaultNewEventTagId ?? old.defaultNewEventTagId)
            |> \.defaultNewEventPeriod .~ (params.defaultNewEventPeriod ?? old.defaultNewEventPeriod)
        
        self.settingSubject.send(new)
        return new
    }
    
    public var currentEventSetting: AnyPublisher<EventSettings, Never> {
        return self.settingSubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
}
