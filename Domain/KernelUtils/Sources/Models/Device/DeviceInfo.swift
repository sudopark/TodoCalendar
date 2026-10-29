//
//  DeviceInfo.swift
//  KernelUtils
//
//  Created by sudo.park on 10/28/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct DeviceInfo: Sendable {
    public var osVersion: String?
    public var appVersion: String?
    public var deviceModel: String?
    public var isiOSAppOnMac: Bool?
    public init() { }
}
