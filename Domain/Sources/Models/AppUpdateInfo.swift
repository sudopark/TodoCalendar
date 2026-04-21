//
//  AppUpdateInfo.swift
//  Domain
//

import Foundation

public struct AppUpdateInfo: Sendable {
    public var forceUpdateVersion: String?
    public var recommendUpdateVersion: String?
    public var latestVersion: String?
    public init() { }
}

public enum AppUpdateRequirement: Sendable, Equatable {
    case forceRequired
    case recommended
}
