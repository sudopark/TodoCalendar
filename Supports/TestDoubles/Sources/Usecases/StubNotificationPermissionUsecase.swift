//
//  StubNotificationPermissionUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 1/21/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain

open class StubNotificationPermissionUsecase: NotificationPermissionUsecase, @unchecked Sendable {
    
    public init() { }
    
    public var stubAuthorizationStatusCheckResult: Result<NotificationAuthorizationStatus, any Error> = .success(.authorized)
    open func checkAuthorizationStatus() async throws -> NotificationAuthorizationStatus {
        switch self.stubAuthorizationStatusCheckResult {
        case .success(let success):
            return success
        case .failure(let failure):
            throw failure
        }
    }
    
    public var stubRequestPermissionResult: Result<Bool, any Error> = .success(true)
    public var didPermissionChanged: ((NotificationAuthorizationStatus) -> Void)?
    open func requestPermission() async throws -> Bool {
        switch self.stubRequestPermissionResult {
        case .success(let success):
            self.didPermissionChanged?(success ? .authorized : .denied)
            return success
        case .failure(let failure):
            throw failure
        }
    }
}
