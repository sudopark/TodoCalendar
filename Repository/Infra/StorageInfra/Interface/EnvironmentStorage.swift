//
//  EnvironmentStorage.swift
//  StorageInfraInterface
//
//  Created by sudo.park on 10/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum EnvironmentKeys: String {
    case needCheckResetWidgetCache
    case needCheckResetCurrentTodo
    case fullScreenAdExposureRecords
    case appColdLaunchHistory
    case colorThemeLicense
    case widgetStyleLicense
    case appPolicy
}

public protocol EnvironmentStorage: AnyObject, Sendable {
    
    func load<T: Decodable>(_ key: String) -> T?
    func update<T: Encodable>(_ key: String, _ value: T)
    func remove(_ key: String)
    func synchronize()
}
