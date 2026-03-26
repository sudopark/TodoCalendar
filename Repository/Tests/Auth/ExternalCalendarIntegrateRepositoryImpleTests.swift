//
//  ExternalCalendarIntegrateRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 1/27/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository

struct ExternalCalendarIntegrateRepositoryImpleTests {

    private let services: [any ExternalCalendarService] = [
        GoogleCalendarService(scopes: [.readOnly])
    ]
    private let spyPool = SpyRemotePool()
    private let spyKeyChain = SpyKeyChainStorage()

    private func makeReposiotry(
        _ accounts: [(ExternalServiceAccountinfo, APICredential)] = []
    ) -> ExternalCalendarIntegrateRepositoryImple {

        accounts.forEach { pair in
            let serviceId = pair.0.serviceIdentifier
            let accountId = pair.0.email ?? ""
            var accountIds: [String] = spyKeyChain.load("\(serviceId)-accounts") ?? []
            accountIds.append(accountId)
            spyKeyChain.update("\(serviceId)-accounts", accountIds)
            spyKeyChain.update("\(serviceId)-\(accountId)-account", ExternalServiceAccountMapper(account: pair.0))
            spyKeyChain.update("\(serviceId)-\(accountId)-credential", APICredentialMapper(credential: pair.1))
        }

        return .init(supportServices: self.services, remotePool: self.spyPool, keyChainStore: self.spyKeyChain)
    }

    private let googleService: GoogleCalendarService = .init(scopes: [.readOnly])

    private var dummyGoogleAccount: ExternalServiceAccountinfo {
        return .init(googleService.identifier, email: "old-email")
    }

    private var googleCredential: APICredential {
        return .init(accessToken: "old-google-access")
    }
}

extension ExternalCalendarIntegrateRepositoryImpleTests {

    // load accounts — pool에 credential 세팅
    @Test func repository_loadAccounts() async throws {
        // given
        let repository = self.makeReposiotry([(self.dummyGoogleAccount, self.googleCredential)])

        // when
        let accounts = try await repository.loadIntegratedAccounts()

        // then
        #expect(accounts.count == 1)
        #expect(accounts.first?.email == "old-email")
        let setupToken = spyPool.setupCredentials["\(googleService.identifier)-old-email"]
        #expect(setupToken == "old-google-access")
    }

    // save credential — pool setup + keychain 저장
    @Test func repository_saveCredential() async throws {
        // given
        let repository = self.makeReposiotry()
        let accountsBeforeSave = try await repository.loadIntegratedAccounts()

        // when
        let googleCredential = GoogleOAuth2Credential(
            idToken: "id", accessToken: "access", refreshToken: "ref"
        ) |> \.email .~ "google"
        let saved = try await repository.save(googleCredential, for: self.googleService)

        let accountsAfterSave = try await repository.loadIntegratedAccounts()
        let storedCredential: APICredentialMapper? = spyKeyChain.load("\(googleService.identifier)-google-credential")
        let accountIds: [String]? = spyKeyChain.load("\(googleService.identifier)-accounts")

        // then
        #expect(accountsBeforeSave.isEmpty)
        #expect(saved.email == "google")
        #expect(accountsAfterSave.map { $0.email } == ["google"])
        #expect(storedCredential?.credential.accessToken == "access")
        #expect(storedCredential?.credential.refreshToken == "ref")
        #expect(accountIds == ["google"])
        #expect(spyPool.setupCredentials["\(googleService.identifier)-google"] == "access")
    }

    // old key로 저장된 계정이 loadIntegratedAccounts 시 마이그레이션되어 정상 로드
    @Test func repository_whenOldKeyAccountExists_migrateAndLoad() async throws {
        // given
        let serviceId = googleService.identifier
        let oldAccountKey = "\(serviceId)-account"
        let oldCredentialKey = "\(serviceId)-credential"
        let account = ExternalServiceAccountMapper(account: dummyGoogleAccount)
        let credential = APICredentialMapper(credential: googleCredential)
        spyKeyChain.update(oldAccountKey, account)
        spyKeyChain.update(oldCredentialKey, credential)
        let repository = ExternalCalendarIntegrateRepositoryImple(
            supportServices: services, remotePool: spyPool, keyChainStore: spyKeyChain
        )

        // when
        let accounts = try await repository.loadIntegratedAccounts()

        // then
        #expect(accounts.count == 1)
        #expect(accounts.first?.email == "old-email")
        // old key 삭제됨
        let oldAccount: ExternalServiceAccountMapper? = spyKeyChain.load(oldAccountKey)
        let oldCred: APICredentialMapper? = spyKeyChain.load(oldCredentialKey)
        #expect(oldAccount == nil)
        #expect(oldCred == nil)
        // new key에 저장됨
        let newAccount: ExternalServiceAccountMapper? = spyKeyChain.load("\(serviceId)-old-email-account")
        let newCred: APICredentialMapper? = spyKeyChain.load("\(serviceId)-old-email-credential")
        let accountIds: [String]? = spyKeyChain.load("\(serviceId)-accounts")
        #expect(newAccount?.account.email == "old-email")
        #expect(newCred?.credential.accessToken == "old-google-access")
        #expect(accountIds == ["old-email"])
    }

    // old key가 없으면 마이그레이션 없이 정상 동작
    @Test func repository_whenNoOldKey_loadNormally() async throws {
        // given
        let repository = self.makeReposiotry()

        // when
        let accounts = try await repository.loadIntegratedAccounts()

        // then
        #expect(accounts.isEmpty)
    }

    // remove account — pool remove + keychain 삭제
    @Test func repository_removeAccount() async throws {
        // given
        let repository = self.makeReposiotry([(self.dummyGoogleAccount, self.googleCredential)])
        let accountsBeforeSave = try await repository.loadIntegratedAccounts()

        // when
        try await repository.removeAccount(for: googleService.identifier, accountId: "old-email")

        let accountsAfterSave = try await repository.loadIntegratedAccounts()
        let storedCredential: APICredentialMapper? = spyKeyChain.load("\(googleService.identifier)-old-email-credential")
        let accountIds: [String]? = spyKeyChain.load("\(googleService.identifier)-accounts")

        // then
        #expect(accountsBeforeSave.map { $0.email } == ["old-email"])
        #expect(accountsAfterSave.isEmpty)
        #expect(storedCredential == nil)
        #expect(accountIds == nil)
        #expect(spyPool.removedKeys.contains("\(googleService.identifier)-old-email"))
    }
}


// MARK: - Spy

private final class SpyRemotePool: ExternalCalendarAccountRemotePool, @unchecked Sendable {

    var setupCredentials: [String: String] = [:]
    var removedKeys: Set<String> = []

    func attach(listener: any AutenticatorTokenRefreshListener) { }

    func setup(for serviceId: String, accountId: String, credential: APICredential) {
        setupCredentials["\(serviceId)-\(accountId)"] = credential.accessToken
    }

    func remove(for serviceId: String, accountId: String) {
        removedKeys.insert("\(serviceId)-\(accountId)")
    }

    func remote(for serviceId: String, accountId: String) throws -> any RemoteAPI {
        throw RuntimeError("not implemented")
    }
}
