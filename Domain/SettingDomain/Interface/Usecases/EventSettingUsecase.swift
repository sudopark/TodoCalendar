//
//  EventSettingUsecase.swift
//  SettingDomainInterface
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


public protocol EventSettingUsecase: Sendable {
    
    func loadEventSetting() -> EventSettings
    
    func changeEventSetting(
        _ params: EditEventSettingsParams
    ) throws -> EventSettings
    
    var currentEventSetting: AnyPublisher<EventSettings, Never> { get }
}
