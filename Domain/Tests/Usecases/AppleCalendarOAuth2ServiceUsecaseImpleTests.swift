//
//  AppleCalendarOAuth2ServiceUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 3/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Extensions
import UnitTestHelpKit

@testable import Domain


final class AppleCalendarOAuth2ServiceUsecaseImpleTests {

    private func makeUsecase(
        shouldGrantAccess: Bool = true
    ) -> AppleCalendarOAuth2ServiceUsecaseImple {
        let checker = StubAppleCalendarPermissionChecker()
        checker.stubRequestAccess = shouldGrantAccess
        return AppleCalendarOAuth2ServiceUsecaseImple(permissionChecker: checker)
    }
}


extension AppleCalendarOAuth2ServiceUsecaseImpleTests {

    @Test func usecase_whenAccessGranted_returnCredential() async throws {
        // given
        let usecase = self.makeUsecase(shouldGrantAccess: true)

        // when
        let credential = try await usecase.requestAuthentication()

        // then
        #expect(credential is AppleCalendarCredential)
    }

    @Test func usecase_whenAccessDenied_throwError() async {
        // given
        let usecase = self.makeUsecase(shouldGrantAccess: false)

        // when
        let credential = try? await usecase.requestAuthentication()

        // then
        #expect(credential == nil)
    }

    @Test func usecase_handleOpenURL_alwaysReturnFalse() {
        // given
        let usecase = self.makeUsecase()
        let url = URL(string: "https://example.com")!

        // when
        let handled = usecase.handle(open: url)

        // then
        #expect(handled == false)
    }
}


// MARK: - StubAppleCalendarPermissionChecker

private final class StubAppleCalendarPermissionChecker: AppleCalendarPermissionChecker, @unchecked Sendable {

    var stubRequestAccess: Bool = true
    func requestAccess() async throws -> Bool { stubRequestAccess }

    func checkAccessStatus() -> Bool { stubRequestAccess }
}
