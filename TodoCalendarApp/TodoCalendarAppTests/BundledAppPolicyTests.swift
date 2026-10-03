//
//  BundledAppPolicyTests.swift
//  TodoCalendarAppTests
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Domain
import Repository

@testable import TodoCalendarApp


final class BundledAppPolicyTests { }

extension BundledAppPolicyTests {

    @Test("앱 번들의 app-policy.json 을 기본값으로 받은 repository 가 사용권 7일과 빈 기능 스위치를 답한다")
    func bundledAppPolicy_decodes() {
        // given
        let fileURL = Bundle.main.url(forResource: "app-policy", withExtension: "json")
        let repository = AppPolicyRepositoryImple(
            remoteAPI: NeverCalledRemoteAPI(),
            environmentStorage: UserDefaultEnvironmentStorageImple(suiteName: UUID().uuidString),
            defaultPolicyFileURL: fileURL
        )

        // when
        let policy = repository.loadPolicy()

        // then
        #expect(fileURL != nil)
        #expect(policy == AppPolicy(colorThemeLicense: .init(licenseDays: 7), featureSwitches: [:]))
    }
}


private final class NeverCalledRemoteAPI: RemoteAPI, @unchecked Sendable {

    func request(
        _ method: RemoteAPIMethod,
        _ endpoint: any Endpoint,
        with header: [String: String]?,
        parameters: [String: Any]
    ) async throws -> Data {
        return Data()
    }

    func attach(listener: any AutenticatorTokenRefreshListener) { }

    func setup(credential: APICredential?) { }
}
