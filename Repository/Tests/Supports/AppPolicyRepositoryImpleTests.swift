//
//  AppPolicyRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 10/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import Repository


final class AppPolicyRepositoryImpleTests {

    private let remoteText = #"""
    {
        "color_theme_license": {"enabled": true, "license_days": 14},
        "widget_style_license": {"enabled": true, "license_days": 21},
        "feature_switches": {
            "alpha": {"enabled": true, "min_app_version": "3.1.0", "rollout_percentage": 30},
            "beta": {"enabled": false}
        }
    }
    """#

    private var stubRemote: StubRemoteAPI!

    private func makeRepository(
        storage: FakeEnvironmentStorage = FakeEnvironmentStorage(),
        remoteResult: Result<String, Error>? = nil
    ) -> AppPolicyRepositoryImple {
        self.stubRemote = StubRemoteAPI(responses: [
            .init(
                method: .get,
                endpoint: AppEndpoints.appPolicy,
                resultJsonString: remoteResult ?? .success(self.remoteText)
            )
        ])
        return AppPolicyRepositoryImple(remoteAPI: self.stubRemote, environmentStorage: storage)
    }

    private func refreshedLicense(_ licenseJson: String) async throws -> ColorThemeLicensePolicy? {
        let repository = self.makeRepository(remoteResult: .success(#"""
        {"color_theme_license": \#(licenseJson)}
        """#))
        try await repository.refreshPolicy()
        return repository.loadPolicy()?.colorThemeLicense
    }

    private func refreshedWidgetLicense(_ licenseJson: String) async throws -> WidgetStyleLicensePolicy? {
        let repository = self.makeRepository(remoteResult: .success(#"""
        {"widget_style_license": \#(licenseJson)}
        """#))
        try await repository.refreshPolicy()
        return repository.loadPolicy()?.widgetStyleLicense
    }

    private struct RemoteFailure: Error { }

    private func didThrow(_ action: () async throws -> Void) async -> Bool {
        do {
            try await action()
            return false
        } catch {
            return true
        }
    }
}


// MARK: - 읽기

extension AppPolicyRepositoryImpleTests {

    @Test("받아 둔 정책이 없으면 nil 을 준다")
    func repository_loadPolicy_whenNoCache_isNil() {
        // given
        let repository = self.makeRepository()

        // when
        let policy = repository.loadPolicy()

        // then
        #expect(policy == nil)
    }

    @Test("이전에 받아 둔 정책을 새 인스턴스에서도 읽는다")
    func repository_loadPolicy_whenCached_returnsCache() async throws {
        // given
        let storage = FakeEnvironmentStorage()
        try await self.makeRepository(storage: storage).refreshPolicy()

        // when
        let policy = self.makeRepository(storage: storage).loadPolicy()

        // then
        #expect(policy?.colorThemeLicense == .init(isEnabled: true, licenseDays: 14))
        #expect(policy?.widgetStyleLicense == .init(isEnabled: true, licenseDays: 21))
    }
}


// MARK: - 갱신

extension AppPolicyRepositoryImpleTests {

    @Test("갱신하면 받은 정책을 캐시에 쓰고 기능 스위치도 그대로 돌려준다")
    func repository_refreshPolicy_cachesReceivedPolicyWithSwitches() async throws {
        // given
        let repository = self.makeRepository()

        // when
        try await repository.refreshPolicy()
        let policy = repository.loadPolicy()

        // then
        #expect(policy == AppPolicy(
            colorThemeLicense: .init(isEnabled: true, licenseDays: 14),
            widgetStyleLicense: .init(isEnabled: true, licenseDays: 21),
            featureSwitches: [
                "alpha": .init(isEnabled: true, minAppVersion: "3.1.0", rolloutPercentage: 30),
                "beta": .init(isEnabled: false)
            ]
        ))
    }

    @Test("min_app_version 이 없는 스위치는 nil 로 읽는다")
    func repository_refreshPolicy_whenNoMinAppVersion_isNil() async throws {
        // given
        let repository = self.makeRepository()

        // when
        try await repository.refreshPolicy()
        let beta = repository.loadPolicy()?.featureSwitches["beta"]

        // then
        #expect(beta?.minAppVersion == nil)
        #expect(beta?.isEnabled == false)
    }

    @Test("rollout_percentage 가 없으면 nil 이고 범위 밖 값은 0~100 으로 맞춘다")
    func repository_refreshPolicy_normalizesRolloutPercentage() async throws {
        // given
        let repository = self.makeRepository(remoteResult: .success(#"""
        {"feature_switches": {
            "none": {"enabled": true},
            "over": {"enabled": true, "rollout_percentage": 150},
            "under": {"enabled": true, "rollout_percentage": -5},
            "edge": {"enabled": true, "rollout_percentage": 0}
        }}
        """#))

        // when
        try await repository.refreshPolicy()
        let switches = repository.loadPolicy()?.featureSwitches

        // then
        #expect(switches?["none"]?.rolloutPercentage == nil)
        #expect(switches?["over"]?.rolloutPercentage == 100)
        #expect(switches?["under"]?.rolloutPercentage == 0)
        #expect(switches?["edge"]?.rolloutPercentage == 0)
    }

    @Test("갱신은 앱 정책 JSON 엔드포인트를 GET 으로 요청한다")
    func repository_refreshPolicy_requestsAppPolicyEndpoint() async throws {
        // given
        let repository = self.makeRepository()

        // when
        try await repository.refreshPolicy()

        // then
        #expect(self.stubRemote.didRequestedMethod == .get)
        #expect(self.stubRemote.didRequestedPath?.hasSuffix("/app-policy.json") == true)
    }
}


// MARK: - 사용권 항목 속성별 무효 처리

extension AppPolicyRepositoryImpleTests {

    @Test("사용권 항목이 없으면 nil 이다")
    func repository_refreshPolicy_whenLicenseItemMissing_isNil() async throws {
        // given
        let repository = self.makeRepository(remoteResult: .success(#"""
        {"feature_switches": {"alpha": {"enabled": true}}}
        """#))

        // when
        try await repository.refreshPolicy()
        let policy = repository.loadPolicy()

        // then
        #expect(policy?.colorThemeLicense == nil)
        #expect(policy?.featureSwitches["alpha"] == .init(isEnabled: true))
    }

    @Test("enabled 가 없으면 그 속성만 nil 로 두고 기간은 살린다")
    func repository_refreshPolicy_whenEnabledMissing_dropsOnlyEnabled() async throws {
        // when
        let license = try await self.refreshedLicense(#"{"license_days": 3}"#)

        // then
        #expect(license == .init(isEnabled: nil, licenseDays: 3))
    }

    @Test("license_days 가 없으면 그 속성만 nil 로 두고 enabled 는 살린다")
    func repository_refreshPolicy_whenDaysMissing_dropsOnlyDays() async throws {
        // when
        let license = try await self.refreshedLicense(#"{"enabled": false}"#)

        // then
        #expect(license == .init(isEnabled: false, licenseDays: nil))
    }

    @Test("license_days 가 0 이하면 그 속성만 nil 로 두고 enabled 는 살린다", arguments: [0, -3])
    func repository_refreshPolicy_whenInvalidDays_dropsOnlyDays(_ days: Int) async throws {
        // when
        let license = try await self.refreshedLicense(#"{"enabled": true, "license_days": \#(days)}"#)

        // then
        #expect(license == .init(isEnabled: true, licenseDays: nil))
    }

    @Test("enabled false 는 그대로 읽는다")
    func repository_refreshPolicy_whenDisabled_keepsGateOff() async throws {
        // when
        let license = try await self.refreshedLicense(#"{"enabled": false, "license_days": 14}"#)

        // then
        #expect(license == .init(isEnabled: false, licenseDays: 14))
    }
}


// MARK: - 위젯 사용권 항목 속성별 무효 처리

extension AppPolicyRepositoryImpleTests {

    @Test("위젯 사용권 항목을 enabled·license_days 로 읽는다")
    func repository_refreshPolicy_decodesWidgetStyleLicense() async throws {
        // when
        let license = try await self.refreshedWidgetLicense(#"{"enabled": true, "license_days": 21}"#)

        // then
        #expect(license == .init(isEnabled: true, licenseDays: 21))
    }

    @Test("위젯 사용권 항목이 없으면 nil 이다")
    func repository_refreshPolicy_whenWidgetLicenseItemMissing_isNil() async throws {
        // given
        let repository = self.makeRepository(remoteResult: .success(#"""
        {"color_theme_license": {"enabled": true, "license_days": 14}}
        """#))

        // when
        try await repository.refreshPolicy()
        let policy = repository.loadPolicy()

        // then
        #expect(policy?.widgetStyleLicense == nil)
        #expect(policy?.colorThemeLicense == .init(isEnabled: true, licenseDays: 14))
    }

    @Test("위젯 사용권의 enabled 가 없으면 그 속성만 nil 로 두고 기간은 살린다")
    func repository_refreshPolicy_whenWidgetLicenseEnabledMissing_dropsOnlyEnabled() async throws {
        // when
        let license = try await self.refreshedWidgetLicense(#"{"license_days": 3}"#)

        // then
        #expect(license == .init(isEnabled: nil, licenseDays: 3))
    }

    @Test("위젯 사용권의 license_days 가 없으면 그 속성만 nil 로 두고 enabled 는 살린다")
    func repository_refreshPolicy_whenWidgetLicenseDaysMissing_dropsOnlyDays() async throws {
        // when
        let license = try await self.refreshedWidgetLicense(#"{"enabled": false}"#)

        // then
        #expect(license == .init(isEnabled: false, licenseDays: nil))
    }

    @Test(
        "위젯 사용권의 license_days 가 0 이하면 그 속성만 nil 로 두고 enabled 는 살린다",
        arguments: [0, -3]
    )
    func repository_refreshPolicy_whenWidgetLicenseInvalidDays_dropsOnlyDays(_ days: Int) async throws {
        // when
        let license = try await self.refreshedWidgetLicense(
            #"{"enabled": true, "license_days": \#(days)}"#
        )

        // then
        #expect(license == .init(isEnabled: true, licenseDays: nil))
    }
}


// MARK: - 갱신 실패

extension AppPolicyRepositoryImpleTests {

    @Test("원격 요청이 실패하면 throw 하며 이전 캐시를 유지한다")
    func repository_refreshPolicy_whenRemoteFails_keepsPrevious() async throws {
        // given
        let storage = FakeEnvironmentStorage()
        try await self.makeRepository(storage: storage).refreshPolicy()
        let failingRepository = self.makeRepository(storage: storage, remoteResult: .failure(RemoteFailure()))

        // when
        let didThrow = await self.didThrow { try await failingRepository.refreshPolicy() }
        let policy = failingRepository.loadPolicy()

        // then
        #expect(didThrow == true)
        #expect(policy?.colorThemeLicense == .init(isEnabled: true, licenseDays: 14))
    }

    @Test("받은 JSON 을 읽지 못하면 throw 하며 이전 캐시를 유지한다")
    func repository_refreshPolicy_whenDecodingFails_keepsPrevious() async throws {
        // given
        let storage = FakeEnvironmentStorage()
        try await self.makeRepository(storage: storage).refreshPolicy()
        let brokenRepository = self.makeRepository(storage: storage, remoteResult: .success("not a json"))

        // when
        let didThrow = await self.didThrow { try await brokenRepository.refreshPolicy() }
        let policy = brokenRepository.loadPolicy()

        // then
        #expect(didThrow == true)
        #expect(policy?.colorThemeLicense == .init(isEnabled: true, licenseDays: 14))
    }

    @Test("원격이 실패하고 캐시도 없으면 정책은 nil 이다")
    func repository_refreshPolicy_whenRemoteFailsWithoutCache_isNil() async {
        // given
        let repository = self.makeRepository(remoteResult: .failure(RemoteFailure()))

        // when
        let didThrow = await self.didThrow { try await repository.refreshPolicy() }
        let policy = repository.loadPolicy()

        // then
        #expect(didThrow == true)
        #expect(policy == nil)
    }
}
