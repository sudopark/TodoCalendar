//
//  NotificationPermissionUsecaseImpleTests.swift
//  Domain
//
//  Created by sudo.park on 1/16/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
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
            _ status: NotificationAuthorizationStatus?,
            _ shouldFail: Bool,
            _ expectResult: Result<NotificationAuthorizationStatus, any Error>
        ) async {
            // given
            self.stubNotificationService.stubAuthorizeStatus = status
            self.stubNotificationService.shouldFailCheckAuthorizationStatus = shouldFail

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
        await parameterizeTest(.authorized, false, .success(.authorized))
        await parameterizeTest(.denied, false, .success(.denied))
        await parameterizeTest(.notDetermined, false, .success(.notDetermined))
        // provisional/ephemeral → throw 매핑은 UNLocalNotificationServiceImple 어댑터로 이동. 여기선 throw 경로만 유지
        await parameterizeTest(nil, true, .failure(RuntimeError("failed")))
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
