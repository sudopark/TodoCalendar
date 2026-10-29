//
//  DeviceInfoFetchService.swift
//  KernelUtils
//
//  Created by sudo.park on 10/28/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol DeviceInfoFetchService: Sendable {
    @MainActor
    func fetchDeviceInfo() async -> DeviceInfo
    func fetchAppVersion() -> String?
}
