//
//  ExternalCalendarAccountRemotePoolImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 3/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Domain
import Extensions

@testable import Repository


@Suite("ExternalCalendarAccountRemotePoolImpleTests", .serialized)
final class ExternalCalendarAccountRemotePoolImpleTests {

    private let serviceId = "google"
    private let accountId1 = "user1@gmail.com"
    private let accountId2 = "user2@gmail.com"

    private func makePool() -> (ExternalCalendarAccountRemotePoolImple, SpyRemoteFactory) {
        let factory = SpyRemoteFactory()
        let pool = ExternalCalendarAccountRemotePoolImple(factory: factory)
        return (pool, factory)
    }

    private func credential(token: String) -> APICredential {
        return APICredential(accessToken: token)
    }
}


extension ExternalCalendarAccountRemotePoolImpleTests {

    // setup 후 remote 획득 성공
    @Test func setup_then_remote_returns_created_instance() throws {
        // given
        let (pool, _) = makePool()

        // when
        pool.setup(for: serviceId, accountId: accountId1, credential: credential(token: "t1"))

        // then
        let remote = try pool.remote(for: serviceId, accountId: accountId1) as? SpyRemote
        #expect(remote?.credential?.accessToken == "t1")
    }

    // setup 없이 remote 접근 시 throw
    @Test func remote_without_setup_throws() {
        // given
        let (pool, _) = makePool()

        // when / then
        #expect(throws: (any Error).self) {
            _ = try pool.remote(for: serviceId, accountId: accountId1)
        }
    }

    // setup 2회 호출 시 factory는 1번만, credential은 갱신
    @Test func setup_twice_reuses_existing_remote_and_updates_credential() throws {
        // given
        let (pool, factory) = makePool()

        // when
        pool.setup(for: serviceId, accountId: accountId1, credential: credential(token: "t1"))
        pool.setup(for: serviceId, accountId: accountId1, credential: credential(token: "t2"))

        // then
        #expect(factory.makeCallCount == 1)
        let remote = try pool.remote(for: serviceId, accountId: accountId1) as? SpyRemote
        #expect(remote?.credential?.accessToken == "t2")
    }

    // remove 후 remote 접근 시 throw
    @Test func after_remove_remote_throws() {
        // given
        let (pool, _) = makePool()
        pool.setup(for: serviceId, accountId: accountId1, credential: credential(token: "t1"))

        // when
        pool.remove(for: serviceId, accountId: accountId1)

        // then
        #expect(throws: (any Error).self) {
            _ = try pool.remote(for: serviceId, accountId: accountId1)
        }
    }

    // remove 시 credential nil로 정리
    @Test func remove_clears_credential_on_remote() throws {
        // given
        let (pool, _) = makePool()
        pool.setup(for: serviceId, accountId: accountId1, credential: credential(token: "t1"))
        let remote = try pool.remote(for: serviceId, accountId: accountId1) as? SpyRemote

        // when
        pool.remove(for: serviceId, accountId: accountId1)

        // then
        #expect(remote?.credential == nil)
    }

    // accountId별 독립 관리
    @Test func manages_remotes_per_accountId_independently() throws {
        // given
        let (pool, _) = makePool()
        pool.setup(for: serviceId, accountId: accountId1, credential: credential(token: "t1"))
        pool.setup(for: serviceId, accountId: accountId2, credential: credential(token: "t2"))

        // when
        pool.remove(for: serviceId, accountId: accountId1)

        // then
        #expect(throws: (any Error).self) {
            _ = try pool.remote(for: serviceId, accountId: accountId1)
        }
        let remote2 = try pool.remote(for: serviceId, accountId: accountId2) as? SpyRemote
        #expect(remote2?.credential?.accessToken == "t2")
    }

    // attach 후 setup 시 새 remote에 listener 자동 부착
    @Test func new_remote_gets_listener_after_attach() throws {
        // given
        let (pool, _) = makePool()
        let listener = SpyListener()
        pool.attach(listener: listener)

        // when
        pool.setup(for: serviceId, accountId: accountId1, credential: credential(token: "t1"))

        // then
        let remote = try pool.remote(for: serviceId, accountId: accountId1) as? SpyRemote
        #expect(remote?.attachedListener != nil)
    }

    // attach 시 기존 remote에도 listener 즉시 부착
    @Test func existing_remotes_get_listener_on_attach() throws {
        // given
        let (pool, _) = makePool()
        pool.setup(for: serviceId, accountId: accountId1, credential: credential(token: "t1"))

        // when
        let listener = SpyListener()
        pool.attach(listener: listener)

        // then
        let remote = try pool.remote(for: serviceId, accountId: accountId1) as? SpyRemote
        #expect(remote?.attachedListener != nil)
    }

    // 지원하지 않는 serviceId는 무시
    @Test func setup_with_unsupported_serviceId_is_ignored() {
        // given
        let (pool, _) = makePool()

        // when
        pool.setup(for: "unsupported", accountId: accountId1, credential: credential(token: "t1"))

        // then
        #expect(throws: (any Error).self) {
            _ = try pool.remote(for: "unsupported", accountId: accountId1)
        }
    }
}


// MARK: - Spy

private final class SpyRemote: RemoteAPI, @unchecked Sendable {

    var credential: APICredential?
    var attachedListener: (any AutenticatorTokenRefreshListener)?

    func request(
        _ method: RemoteAPIMethod,
        _ endpoint: any Endpoint,
        with header: [String: String]?,
        parameters: [String: Any]
    ) async throws -> Data {
        throw RuntimeError("not implemented")
    }

    func setup(credential: APICredential?) {
        self.credential = credential
    }

    func attach(listener: any AutenticatorTokenRefreshListener) {
        self.attachedListener = listener
    }
}

private final class SpyListener: AutenticatorTokenRefreshListener, @unchecked Sendable {
    func oauthAutenticator(_ authenticator: (any APIAuthenticator)?, didRefresh credential: APICredential) { }
    func oauthAutenticator(_ authenticator: (any APIAuthenticator)?, didRefreshFailed error: any Error) { }
}

private final class SpyRemoteFactory: ExternalCalendarRemoteFactory, @unchecked Sendable {

    var makeCallCount = 0

    func make(serviceId: String, accountId: String) -> (any RemoteAPI)? {
        guard serviceId == "google" else { return nil }
        makeCallCount += 1
        return SpyRemote()
    }
}
