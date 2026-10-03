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

    private let bundledText = #"{"color_theme_license": {"license_days": 7}}"#
    private let remoteText = #"""
    {
        "color_theme_license": {"license_days": 14},
        "feature_switches": {
            "alpha": {"enabled": true, "min_app_version": "3.1.0"},
            "beta": {"enabled": false}
        }
    }
    """#

    private func writeTemporaryFile(_ text: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-policy-\(UUID().uuidString).json")
        try? text.data(using: .utf8)?.write(to: url)
        return url
    }

    private var stubRemote: StubRemoteAPI!

    private func makeRepository(
        storage: FakeEnvironmentStorage = FakeEnvironmentStorage(),
        remoteResult: Result<String, Error>? = nil,
        defaultPolicyFileURL: URL? = nil
    ) -> AppPolicyRepositoryImple {
        self.stubRemote = StubRemoteAPI(responses: [
            .init(
                method: .get,
                endpoint: AppEndpoints.appPolicy,
                resultJsonString: remoteResult ?? .success(self.remoteText)
            )
        ])
        return AppPolicyRepositoryImple(
            remoteAPI: self.stubRemote,
            environmentStorage: storage,
            defaultPolicyFileURL: defaultPolicyFileURL ?? self.writeTemporaryFile(self.bundledText)
        )
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

    @Test("받아 둔 정책이 없으면 번들 기본값을 준다")
    func repository_loadPolicy_whenNoCache_returnsDefault() {
        // given
        let repository = self.makeRepository()

        // when
        let policy = repository.loadPolicy()

        // then
        #expect(policy == AppPolicy(colorThemeLicense: .init(licenseDays: 7)))
    }

    @Test("받아 둔 정책이 있으면 번들 기본값보다 앞선다")
    func repository_loadPolicy_whenCached_prefersCacheOverDefault() async throws {
        // given
        let storage = FakeEnvironmentStorage()
        try await self.makeRepository(storage: storage).refreshPolicy()

        // when
        let policy = self.makeRepository(storage: storage).loadPolicy()

        // then
        #expect(policy?.colorThemeLicense == .init(licenseDays: 14))
    }

    @Test("기본값 파일이 없거나 깨졌으면 기본값은 nil 이다", arguments: ["missing", "not a json"])
    func repository_loadPolicy_whenDefaultFileMissingOrBroken_isNil(_ content: String) {
        // given
        let fileURL = content == "missing"
            ? URL(fileURLWithPath: "/nonexistent/app-policy.json")
            : self.writeTemporaryFile(content)
        let repository = self.makeRepository(defaultPolicyFileURL: fileURL)

        // when
        let policy = repository.loadPolicy()

        // then
        #expect(policy == nil)
    }

    @Test("기본값 파일의 기간이 0 이하면 사용권 정책만 nil 로 보고 기능 스위치는 남긴다", arguments: [0, -3])
    func repository_loadPolicy_whenDefaultFileHasInvalidDays_dropsOnlyLicense(_ days: Int) {
        // given
        let fileURL = self.writeTemporaryFile(#"""
        {"color_theme_license": {"license_days": \#(days)}, "feature_switches": {"alpha": {"enabled": true}}}
        """#)
        let repository = self.makeRepository(defaultPolicyFileURL: fileURL)

        // when
        let policy = repository.loadPolicy()

        // then
        #expect(policy == AppPolicy(featureSwitches: ["alpha": .init(isEnabled: true)]))
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
            colorThemeLicense: .init(licenseDays: 14),
            featureSwitches: [
                "alpha": .init(isEnabled: true, minAppVersion: "3.1.0"),
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

    @Test("받은 기간이 0 이하면 사용권 정책만 nil 로 보고 나머지는 캐시한다", arguments: [0, -3])
    func repository_refreshPolicy_whenInvalidDays_dropsOnlyLicense(_ days: Int) async throws {
        // given
        let repository = self.makeRepository(remoteResult: .success(#"""
        {"color_theme_license": {"license_days": \#(days)}, "feature_switches": {"alpha": {"enabled": true}}}
        """#))

        // when
        try await repository.refreshPolicy()
        let policy = repository.loadPolicy()

        // then
        #expect(policy == AppPolicy(featureSwitches: ["alpha": .init(isEnabled: true)]))
    }

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
        #expect(policy?.colorThemeLicense == .init(licenseDays: 14))
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
        #expect(policy?.colorThemeLicense == .init(licenseDays: 14))
    }

    @Test("원격이 실패해도 캐시가 없으면 번들 기본값으로 읽는다")
    func repository_refreshPolicy_whenRemoteFailsWithoutCache_loadsDefault() async {
        // given
        let repository = self.makeRepository(remoteResult: .failure(RemoteFailure()))

        // when
        let didThrow = await self.didThrow { try await repository.refreshPolicy() }
        let policy = repository.loadPolicy()

        // then
        #expect(didThrow == true)
        #expect(policy == AppPolicy(colorThemeLicense: .init(licenseDays: 7)))
    }
}
