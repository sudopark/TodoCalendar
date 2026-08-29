//
//  NeverRemoveAuthStorageTests.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Domain
import Repository

@testable import TodoCalendarApp


final class NeverRemoveAuthStorageTests {

    private func makeSUT(
        seedAuth: Auth? = Auth(uid: "uid", accessToken: "old_token", refreshToken: "old_refresh")
    ) -> (NeverRemoveAuthStorage, AuthStoreImple) {
        let authStore = AuthStoreImple(
            keyChainStorage: FakeKeyChainStore(),
            environmentStorage: FakeEnvironmentStorage()
        )
        if let seedAuth {
            authStore.saveAuth(seedAuth)
        }
        let sut = NeverRemoveAuthStorage(storage: authStore)
        return (sut, authStore)
    }
}

// MARK: - 세션 보존 (삭제 무력화)

extension NeverRemoveAuthStorageTests {

    @Test("removeCredential을 호출해도 저장된 로그인 세션이 지워지지 않는다")
    func removeCredential_keepsSessionAlive() {
        // given
        let (sut, authStore) = self.makeSUT()

        // when
        sut.removeCredential()

        // then
        #expect(authStore.loadCurrentAuth()?.uid == "uid")
    }

    @Test("removeAuth를 호출해도 저장된 로그인 세션이 지워지지 않는다")
    func removeAuth_keepsSessionAlive() {
        // given
        let (sut, authStore) = self.makeSUT()

        // when
        sut.removeAuth()

        // then
        #expect(authStore.loadCurrentAuth()?.uid == "uid")
    }
}

// MARK: - 나머지 동작은 authStore에 위임

extension NeverRemoveAuthStorageTests {

    @Test("loadCredential은 authStore에 저장된 인증 정보를 그대로 반환한다")
    func loadCredential_returnsUnderlyingCredential() {
        // given
        let (sut, _) = self.makeSUT()

        // when
        let credential = sut.loadCredential()

        // then
        #expect(credential?.accessToken == "old_token")
    }

    @Test("updateCredential은 authStore에 반영된다")
    func updateCredential_updatesUnderlyingStore() {
        // given
        let (sut, authStore) = self.makeSUT()

        // when
        var newCredential = APICredential(accessToken: "new_token")
        newCredential.refreshToken = "new_refresh"
        sut.updateCredential(newCredential)

        // then
        #expect(authStore.loadCurrentAuth()?.accessToken == "new_token")
    }
}


private final class FakeKeyChainStore: KeyChainStorage, @unchecked Sendable {

    private var dataMap: [String: Data] = [:]

    func setupSharedGroup(_ identifier: String) { }

    func load<T>(_ key: String) -> T? where T: Decodable {
        return self.dataMap[key]
            .flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    func update<T>(_ key: String, _ value: T) where T: Encodable {
        guard let data = try? JSONEncoder().encode(value)
        else { return }
        self.dataMap[key] = data
    }

    func remove(_ key: String) {
        self.dataMap[key] = nil
    }
}

private final class FakeEnvironmentStorage: EnvironmentStorage, @unchecked Sendable {

    private var storage: [String: String] = [:]

    func load<T>(_ key: String) -> T? where T: Decodable {
        return self.storage[key]
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    func update<T>(_ key: String, _ value: T) where T: Encodable {
        guard let data = try? JSONEncoder().encode(value),
              let dataText = String(data: data, encoding: .utf8)
        else { return }
        self.storage[key] = dataText
    }

    func remove(_ key: String) {
        self.storage.removeValue(forKey: key)
    }

    func synchronize() { }
}
