//
//  StubDeviceInfoFetchService.swift
//  DomainTests
//
//  Created by sudo.park on 12/4/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics

@testable import Domain


struct StubDeviceInfoFetchService: DeviceInfoFetchService {
    
    @MainActor
    func fetchDeviceInfo() async -> DeviceInfo {
        return DeviceInfo()
            |> \.appVersion .~ "app"
            |> \.osVersion .~ "os"
            |> \.deviceModel .~ "model"
    }
}
