//
//  StubEventShareSettingUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Prelude
import Optics

open class StubEventShareSettingUsecase: EventShareSettingUsecase, @unchecked Sendable {

    public init() { }

    public var stubSetting: EventShareSettings = .init()
    private let settingSubject = CurrentValueSubject<EventShareSettings?, Never>(nil)

    open func loadEventShareSetting() -> EventShareSettings {
        self.settingSubject.send(self.stubSetting)
        return self.stubSetting
    }

    public var didChangeEventShareParams: EditEventShareSettingsParams?
    open func changeEventShareSetting(_ params: EditEventShareSettingsParams) throws -> EventShareSettings {
        self.didChangeEventShareParams = params
        let new = self.stubSetting.update(params)
        self.stubSetting = new
        self.settingSubject.send(new)
        return new
    }

    public var currentEventShareSetting: AnyPublisher<EventShareSettings, Never> {
        return self.settingSubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
}
