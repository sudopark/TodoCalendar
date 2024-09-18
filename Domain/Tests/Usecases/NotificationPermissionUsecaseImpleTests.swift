//
//  NotificationPermissionUsecaseImpleTests.swift
//  Domain
//
//  Created by sudo.park on 1/16/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import UserNotifications
import Extensions
import UnitTestHelpKit

@testable import Domain


class NotificationPermissionUsecaseImpleTests: BaseTestCase {
    
    private var stubNotificationService: StubLocalNotificationService!
    
    override func setUpWithError() throws {
        self.stubNotificationService = .init()
    }
    
    override func tearDownWithError() throws {
        self.stubNotificationService = nil
    }
    
    private func makeUsecase() -> NotificationPermissionUsecaseImple {
        
        return .init(notificationService: self.stubNotificationService)
    }
}


extension NotificationPermissionUsecaseImpleTests {
    
    func testUsecase_checkAuthorizationStatus() async {
        // given
        let usecase = self.makeUsecase()
        
        func parameterizeTest(
            _ status: UNAuthorizationStatus,
            _ expectResult: Result<NotificationAuthorizationStatus, any Error>
        ) async {
            // given
            self.stubNotificationService.stubAuthorizeStatus = status
            
            // when
            let authStatus = try? await usecase.checkAuthorizationStatus()
            
            // then
            switch expectResult {
            case .success(let value):
                XCTAssertEqual(authStatus, value)
                
            case .failure:
                XCTAssertNil(authStatus)
            }
        }
        
        // when + then
        await parameterizeTest(.authorized, .success(.authorized))
        await parameterizeTest(.denied, .success(.denied))
        await parameterizeTest(.notDetermined, .success(.notDetermined))
        await parameterizeTest(.provisional, .failure(RuntimeError("failed")))
        await parameterizeTest(.ephemeral, .failure(RuntimeError("failed")))
    }
    
    func testUsecase_requestAuthorize() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let result = try await usecase.requestPermission()
        
        // then
        XCTAssertEqual(result, true)
    }
}
