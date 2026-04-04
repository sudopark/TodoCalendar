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
        authorizationStatus: AppleCalendarAuthorizationStatus = .notDetermined,
        shouldGrantAccess: Bool = true
    ) -> AppleCalendarOAuth2ServiceUsecaseImple {
        let checker = StubAppleCalendarPermissionChecker()
        checker.stubAuthorizationStatus = authorizationStatus
        checker.stubRequestAccess = shouldGrantAccess
        return AppleCalendarOAuth2ServiceUsecaseImple(permissionChecker: checker)
    }
}


extension AppleCalendarOAuth2ServiceUsecaseImpleTests {

    @Test func usecase_whenAlreadyFullAccess_returnCredentialWithoutRequest() async throws {
        // given
        let usecase = self.makeUsecase(authorizationStatus: .fullAccess)

        // when
        let credential = try await usecase.requestAuthentication()

        // then
        #expect(credential is AppleCalendarCredential)
    }

    @Test func usecase_whenStatusIsDenied_throwDeniedError() async {
        // given
        let usecase = self.makeUsecase(authorizationStatus: .denied)

        // when
        var caughtError: AppleCalendarPermissionFailReason?
        do {
            _ = try await usecase.requestAuthentication()
        } catch let error as AppleCalendarPermissionFailReason {
            caughtError = error
        } catch { }

        // then
        #expect(caughtError == .denied)
    }

    @Test func usecase_whenStatusIsRestricted_throwRestrictedError() async {
        // given
        let usecase = self.makeUsecase(authorizationStatus: .restricted)

        // when
        var caughtError: AppleCalendarPermissionFailReason?
        do {
            _ = try await usecase.requestAuthentication()
        } catch let error as AppleCalendarPermissionFailReason {
            caughtError = error
        } catch { }

        // then
        #expect(caughtError == .restricted)
    }

    @Test func usecase_whenNotDetermined_andGranted_returnCredential() async throws {
        // given
        let usecase = self.makeUsecase(authorizationStatus: .notDetermined, shouldGrantAccess: true)

        // when
        let credential = try await usecase.requestAuthentication()

        // then
        #expect(credential is AppleCalendarCredential)
    }

    @Test func usecase_whenNotDetermined_andDenied_throwDeniedError() async {
        // given
        let checker = StubAppleCalendarPermissionChecker()
        checker.stubAuthorizationStatus = .notDetermined
        checker.stubRequestAccess = false
        checker.stubStatusAfterRequest = .denied
        let usecase = AppleCalendarOAuth2ServiceUsecaseImple(permissionChecker: checker)

        // when
        var caughtError: AppleCalendarPermissionFailReason?
        do {
            _ = try await usecase.requestAuthentication()
        } catch let error as AppleCalendarPermissionFailReason {
            caughtError = error
        } catch { }

        // then
        #expect(caughtError == .denied)
    }

    @Test func usecase_whenWriteOnly_andUpgradeFails_throwWriteOnlyError() async {
        // given
        let checker = StubAppleCalendarPermissionChecker()
        checker.stubAuthorizationStatus = .writeOnly
        checker.stubRequestAccess = false
        checker.stubStatusAfterRequest = .writeOnly
        let usecase = AppleCalendarOAuth2ServiceUsecaseImple(permissionChecker: checker)

        // when
        var caughtError: AppleCalendarPermissionFailReason?
        do {
            _ = try await usecase.requestAuthentication()
        } catch let error as AppleCalendarPermissionFailReason {
            caughtError = error
        } catch { }

        // then
        #expect(caughtError == .writeOnly)
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

    var stubAuthorizationStatus: AppleCalendarAuthorizationStatus = .notDetermined
    var stubStatusAfterRequest: AppleCalendarAuthorizationStatus? = nil
    var stubRequestAccess: Bool = true

    func requestAccess() async throws -> Bool {
        if let afterStatus = stubStatusAfterRequest {
            stubAuthorizationStatus = afterStatus
        }
        return stubRequestAccess
    }

    func checkAuthorizationStatus() -> AppleCalendarAuthorizationStatus {
        stubAuthorizationStatus
    }
}
