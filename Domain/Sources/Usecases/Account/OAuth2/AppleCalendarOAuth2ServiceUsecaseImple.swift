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
        let granted = try await permissionChecker.requestAccess()
        guard granted else {
            throw RuntimeError("calendar_access_denied")
        }
        return AppleCalendarCredential()
    }

    public func handle(open url: URL) -> Bool {
        return false
    }
}
