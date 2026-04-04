//
//  AppleCalendarOAuth2ServiceUsecaseImple.swift
//  Domain
//
//  Created by sudo.park on 3/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions


public final class AppleCalendarOAuth2ServiceUsecaseImple: OAuth2ServiceUsecase, @unchecked Sendable {

    public typealias CredentialType = AppleCalendarCredential

    private let permissionChecker: any AppleCalendarPermissionChecker

    public init(permissionChecker: any AppleCalendarPermissionChecker) {
        self.permissionChecker = permissionChecker
    }

    @MainActor
    public func requestAuthentication() async throws -> AppleCalendarCredential {
        let status = permissionChecker.checkAuthorizationStatus()
        switch status {
        case .fullAccess:
            return AppleCalendarCredential()
        case .denied:
            throw AppleCalendarPermissionFailReason.denied
        case .restricted:
            throw AppleCalendarPermissionFailReason.restricted
        case .notDetermined, .writeOnly:
            return try await requestAndVerify()
        }
    }

    public func handle(open url: URL) -> Bool {
        return false
    }
}


// MARK: - private

extension AppleCalendarOAuth2ServiceUsecaseImple {

    @MainActor
    private func requestAndVerify() async throws -> AppleCalendarCredential {
        let granted = try await permissionChecker.requestAccess()
        guard granted else {
            throw permissionChecker.checkAuthorizationStatus().asFailReason()
        }
        return AppleCalendarCredential()
    }
}


// MARK: - AppleCalendarAuthorizationStatus + FailReason

private extension AppleCalendarAuthorizationStatus {

    func asFailReason() -> AppleCalendarPermissionFailReason {
        switch self {
        case .writeOnly: return .writeOnly
        case .restricted: return .restricted
        default: return .denied
        }
    }
}
