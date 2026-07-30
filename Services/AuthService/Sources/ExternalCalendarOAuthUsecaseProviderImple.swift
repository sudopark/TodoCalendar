//
//  ExternalCalendarOAuthUsecaseProviderImple.swift
//  AuthService
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain


public final class ExternalCalendarOAuthUsecaseProviderImple: ExternalCalendarOAuthUsecaseProvider, @unchecked Sendable {

    private let topViewControllerFinding: () -> UIViewController?
    private let appleCalendarPermissionChecker: any AppleCalendarPermissionChecker

    public init(
        topViewControllerFinding: @escaping () -> UIViewController?,
        appleCalendarPermissionChecker: any AppleCalendarPermissionChecker
    ) {
        self.topViewControllerFinding = topViewControllerFinding
        self.appleCalendarPermissionChecker = appleCalendarPermissionChecker
    }

    public func usecase(for service: any ExternalCalendarService) -> (any OAuth2ServiceUsecase)? {
        switch service {
        case let google as GoogleCalendarService:
            return GoogleOAuth2ServiceUsecaseImple(
                additionalScope: google.scopes.map { $0.rawValue },
                topViewControllerFinding: self.topViewControllerFinding
            )

        case is AppleCalendarService:
            return AppleCalendarOAuth2ServiceUsecaseImple(permissionChecker: appleCalendarPermissionChecker)

        default:
            return nil
        }
    }
}
