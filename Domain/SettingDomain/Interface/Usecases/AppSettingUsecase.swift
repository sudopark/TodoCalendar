//
//  AppSettingUsecase.swift
//  SettingDomainInterface
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions

// MARK: - EventShareSettingUsecase

public protocol EventShareSettingUsecase: Sendable {

    func loadEventShareSetting() -> EventShareSettings
    func changeEventShareSetting(_ params: EditEventShareSettingsParams) throws -> EventShareSettings

    var currentEventShareSetting: AnyPublisher<EventShareSettings, Never> { get }
}
