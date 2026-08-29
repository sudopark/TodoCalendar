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
    public private(set) var didCheckAuthorizationStatus: Bool?
    open func checkAuthorizationStatus() async throws -> NotificationAuthorizationStatus {
        self.didCheckAuthorizationStatus = true
        switch self.stubAuthorizationStatusCheckResult {
        case .success(let success):
            return success
        case .failure(let failure):
            throw failure
        }
    }
    
    public var stubRequestPermissionResult: Result<Bool, any Error> = .success(true)
    public var didPermissionChanged: ((NotificationAuthorizationStatus) -> Void)?
    public private(set) var didRequestPermission: Bool?
    // 응답 도착 시점을 테스트가 잡아둘 수 있게 하는 게이트 — 요청 이후 동작의 순서를 검증할 때 쓴다.
    public var requestPermissionGate: (@Sendable () async -> Void)?
    open func requestPermission() async throws -> Bool {
        self.didRequestPermission = true
        await self.requestPermissionGate?()
        switch self.stubRequestPermissionResult {
        case .success(let success):
            self.didPermissionChanged?(success ? .authorized : .denied)
            return success
        case .failure(let failure):
            throw failure
        }
    }
}
