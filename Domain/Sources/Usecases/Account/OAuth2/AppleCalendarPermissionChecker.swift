//
//  AppleCalendarPermissionChecker.swift
//  Domain
//
//  Created by sudo.park on 4/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - AppleCalendarAuthorizationStatus

public enum AppleCalendarAuthorizationStatus: Sendable {
    case notDetermined
    case restricted
    case denied
    case fullAccess
    case writeOnly
}


// MARK: - AppleCalendarPermissionChecker

public protocol AppleCalendarPermissionChecker: Sendable {
    func requestAccess() async throws -> Bool
    func checkAuthorizationStatus() -> AppleCalendarAuthorizationStatus
}

extension AppleCalendarPermissionChecker {

    public func isAuthorized() -> Bool {
        return checkAuthorizationStatus() == .fullAccess
    }
}
