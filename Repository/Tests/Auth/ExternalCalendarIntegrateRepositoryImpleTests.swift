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
        GoogleCalendarService(scopes: [.readOnly]),
        AppleCalendarService()
    ]
    private let spyPool = SpyRemotePool()
    private let spyKeyChain = SpyKeyChainStorage()

    private func makeReposiotry(
        _ accounts: [(ExternalServiceAccountinfo, APICredential?)] = [],
        appleAccountOnly: [ExternalServiceAccountinfo] = [],
        applePermissionGranted: Bool = true
    ) -> ExternalCalendarIntegrateRepositoryImple {

        accounts.forEach { pair in
            let serviceId = pair.0.serviceIdentifier
            let accountId = pair.0.email ?? ""
            var accountIds: [String] = spyKeyChain.load("\(serviceId)-accounts") ?? []
            accountIds.append(accountId)
            spyKeyChain.update("\(serviceId)-accounts", accountIds)
            spyKeyChain.update("\(serviceId)-\(accountId)-account", ExternalServiceAccountMapper(account: pair.0))
            if let credential = pair.1 {
                spyKeyChain.update("\(serviceId)-\(accountId)-credential", APICredentialMapper(credential: credential))
            }
        }

        appleAccountOnly.forEach { account in
            let serviceId = account.serviceIdentifier
            let accountId = account.email ?? ""
            var accountIds: [String] = spyKeyChain.load("\(serviceId)-accounts") ?? []
            accountIds.append(accountId)
            spyKeyChain.update("\(serviceId)-accounts", accountIds)
            spyKeyChain.update("\(serviceId)-\(accountId)-account", ExternalServiceAccountMapper(account: account))
        }

        let permissionChecker = StubAppleCalendarPermissionChecker(isGranted: applePermissionGranted)
        return .init(
            supportServices: self.services,
            remotePool: self.spyPool,
            keyChainStore: self.spyKeyChain,
            appleCalendarPermissionChecker: permissionChecker
        )
    }

    private let googleService: GoogleCalendarService = .init(scopes: [.readOnly])
    private let appleService: AppleCalendarService = .init()

    private var dummyGoogleAccount: ExternalServiceAccountinfo {
        return .init(googleService.identifier, email: "old-email")
    }
    
    private var dummyNoCredentialAccount: ExternalServiceAccountinfo {
        return .init(googleService.identifier, email: "no-credential")
    }

    private var googleCredential: APICredential {
        return .init(accessToken: "old-google-access")
    }

    private var dummyAppleAccount: ExternalServiceAccountinfo {
        return .init(appleService.identifier, email: AppleCalendarService.localAccountId)
    }

    private func makeReposiotryWithOldKeyData(
        oldAccount: ExternalServiceAccountinfo,
        oldCredential: APICredential
    ) -> ExternalCalendarIntegrateRepositoryImple {
        let serviceId = oldAccount.serviceIdentifier
        spyKeyChain.update("\(serviceId)-account", ExternalServiceAccountMapper(account: oldAccount))
        spyKeyChain.update("\(serviceId)-credential", APICredentialMapper(credential: oldCredential))
        return .init(
            supportServices: services,
            remotePool: spyPool,
            keyChainStore: spyKeyChain,
            appleCalendarPermissionChecker: StubAppleCalendarPermissionChecker()
        )
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
        let repository = self.makeReposiotryWithOldKeyData(
            oldAccount: dummyGoogleAccount,
            oldCredential: googleCredential
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

    // save Apple Calendar credential — remote pool setup 없이 keychain만 저장
    @Test func repository_saveAppleCalendarCredential() async throws {
        // given
        let repository = self.makeReposiotry()
        let appleService = AppleCalendarService()
        let accountsBeforeSave = try await repository.loadIntegratedAccounts()

        // when
        let saved = try await repository.save(AppleCalendarCredential(), for: appleService)

        let accountsAfterSave = try await repository.loadIntegratedAccounts()
        let accountIds: [String]? = spyKeyChain.load("\(appleService.identifier)-accounts")

        // then
        let localAccountId = AppleCalendarService.localAccountId
        #expect(accountsBeforeSave.isEmpty)
        #expect(saved.email == localAccountId)
        #expect(accountsAfterSave.map { $0.email } == [localAccountId])
        #expect(accountIds == [localAccountId])
        // API credential 저장 없음
        let storedCredential: APICredentialMapper? = spyKeyChain.load("\(appleService.identifier)-\(localAccountId)-credential")
        #expect(storedCredential == nil)
        // remote pool setup 없음
        #expect(spyPool.setupCredentials["\(appleService.identifier)-\(localAccountId)"] == nil)
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


// MARK: - Apple Calendar permission check

extension ExternalCalendarIntegrateRepositoryImpleTests {

    // 애플 캘린더 계정이 있고 권한이 있으면 로드된 계정에 포함
    @Test func repository_whenAppleAccountHasPermission_includeInAccounts() async throws {
        // given
        let repository = self.makeReposiotry(
            appleAccountOnly: [dummyAppleAccount],
            applePermissionGranted: true
        )

        // when
        let accounts = try await repository.loadIntegratedAccounts()

        // then
        let localAccountId = AppleCalendarService.localAccountId
        #expect(accounts.map { $0.email }.contains(localAccountId))
        // keychain 데이터 유지
        let accountIds: [String]? = spyKeyChain.load("\(appleService.identifier)-accounts")
        #expect(accountIds == [localAccountId])
    }

    // 애플 캘린더 계정이 있지만 권한이 없으면 로드 결과에서 제외
    @Test func repository_whenAppleAccountHasNoPermission_excludeFromAccounts() async throws {
        // given
        let repository = self.makeReposiotry(
            appleAccountOnly: [dummyAppleAccount],
            applePermissionGranted: false
        )

        // when
        let accounts = try await repository.loadIntegratedAccounts()

        // then
        let localAccountId = AppleCalendarService.localAccountId
        #expect(!accounts.map { $0.email }.contains(localAccountId))
    }

    // 애플 캘린더 권한이 없으면 저장된 계정 정보도 삭제
    @Test func repository_whenAppleAccountHasNoPermission_removeKeychainData() async throws {
        // given
        let localAccountId = AppleCalendarService.localAccountId
        let repository = self.makeReposiotry(
            appleAccountOnly: [dummyAppleAccount],
            applePermissionGranted: false
        )

        // when
        _ = try await repository.loadIntegratedAccounts()

        // then — 계정 목록 키와 계정 정보 키 모두 삭제됨
        let accountIds: [String]? = spyKeyChain.load("\(appleService.identifier)-accounts")
        let accountMapper: ExternalServiceAccountMapper? = spyKeyChain.load(
            "\(appleService.identifier)-\(localAccountId)-account"
        )
        #expect(accountIds == nil)
        #expect(accountMapper == nil)
    }

    // 구글 계정은 애플 권한 여부와 무관하게 정상 로드
    @Test func repository_googleAccount_notAffectedByApplePermission() async throws {
        // given
        let repository = self.makeReposiotry(
            [(dummyGoogleAccount, googleCredential)],
            applePermissionGranted: false
        )

        // when
        let accounts = try await repository.loadIntegratedAccounts()

        // then
        #expect(accounts.map { $0.email }.contains("old-email"))
    }
}

// MARK: - load accounts with credential

extension ExternalCalendarIntegrateRepositoryImpleTests {
    
    // 연동된 외부 캘린더 로드 중 credentail이 무효한 경우 제외하고 로드 + remote setup
    @Test func repository_whenLoadIntegratedAccount_filterIsNotExpired() async throws {
        // given
        let repository = self.makeReposiotry(
            [
                (dummyGoogleAccount, googleCredential),
                (dummyNoCredentialAccount, nil),
                (dummyAppleAccount, nil)
            ]
        )
        
        // when
        let accounts = try await repository.loadIntegratedAccounts()
        
        // then
        #expect(accounts.map { $0.email } == ["old-email", AppleCalendarService.localAccountId])
    }
    
    @Test func repository_whenAfterLoadIntegratedAccount_setupRemoteCredentialIfNeed() async throws {
        // given
        let repository = self.makeReposiotry(
            [
                (dummyGoogleAccount, googleCredential),
                (dummyNoCredentialAccount, nil),
                (dummyAppleAccount, nil)
            ]
        )
        
        // when
        let _ = try await repository.loadIntegratedAccounts()
        
        // then
        #expect(spyPool.setupCredentials == [
            "\(googleService.identifier)-old-email": "old-google-access"
        ])
    }
}

// MARK: - Spy

private final class StubAppleCalendarPermissionChecker: AppleCalendarPermissionChecker, @unchecked Sendable {
    var isGranted: Bool
    init(isGranted: Bool = true) { self.isGranted = isGranted }
    func requestAccess() async throws -> Bool { isGranted }
    func checkAuthorizationStatus() -> AppleCalendarAuthorizationStatus { isGranted ? .fullAccess : .denied }
}

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
