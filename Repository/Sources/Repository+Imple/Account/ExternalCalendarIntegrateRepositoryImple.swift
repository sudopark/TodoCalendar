//
//  ExternalCalendarIntegrateRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 1/26/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions


public final class ExternalCalendarIntegrateRepositoryImple: ExternalCalendarIntegrateRepository, @unchecked Sendable {

    private let supportServices: [any ExternalCalendarService]
    private let remotePool: any ExternalCalendarAccountRemotePool
    private let keyChainStore: any KeyChainStorage
    private let credentialStore: IntegratedAPICredentialStore
    private let appleCalendarPermissionChecker: any AppleCalendarPermissionChecker

    public init(
        supportServices: [any ExternalCalendarService],
        remotePool: any ExternalCalendarAccountRemotePool,
        keyChainStore: any KeyChainStorage,
        appleCalendarPermissionChecker: any AppleCalendarPermissionChecker
    ) {
        self.supportServices = supportServices
        self.remotePool = remotePool
        self.keyChainStore = keyChainStore
        self.credentialStore = .init(keyChainStore: keyChainStore)
        self.appleCalendarPermissionChecker = appleCalendarPermissionChecker
    }
}


extension ExternalCalendarIntegrateRepositoryImple {

    private func accountListKey(_ serviceId: String) -> String {
        return "\(serviceId)-accounts"
    }

    private func accountKey(_ serviceId: String, _ accountId: String) -> String {
        return "\(serviceId)-\(accountId)-account"
    }

    private func loadAccountIds(for serviceId: String) -> [String] {
        return self.keyChainStore.load(accountListKey(serviceId)) ?? []
    }

    private func saveAccountId(_ accountId: String, for serviceId: String) {
        var ids = loadAccountIds(for: serviceId)
        if !ids.contains(accountId) {
            ids.append(accountId)
        }
        self.keyChainStore.update(accountListKey(serviceId), ids)
    }

    private func remove(_ accountId: String, fromServiceList serviceId: String) {
        var ids = loadAccountIds(for: serviceId)
        ids.removeAll { $0 == accountId }
        if ids.isEmpty {
            self.keyChainStore.remove(accountListKey(serviceId))
        } else {
            self.keyChainStore.update(accountListKey(serviceId), ids)
        }
    }

    private func migrateOldKeychainAccountsIfNeeded() {
        supportServices.forEach { service in
            let serviceId = service.identifier
            let oldAccountKey = "\(serviceId)-account"
            guard let mapper: ExternalServiceAccountMapper = keyChainStore.load(oldAccountKey)
            else { return }

            let accountId = mapper.account.email ?? ""
            keyChainStore.update(accountKey(serviceId, accountId), mapper)

            let oldCredentialKey = "\(serviceId)-credential"
            if let credentialMapper: APICredentialMapper = keyChainStore.load(oldCredentialKey) {
                credentialStore.saveCredential(for: serviceId, accountId: accountId, credentialMapper.credential)
                keyChainStore.remove(oldCredentialKey)
            }

            saveAccountId(accountId, for: serviceId)
            keyChainStore.remove(oldAccountKey)
        }
    }

    public func loadIntegratedAccounts() async throws -> [ExternalServiceAccountinfo] {
        migrateOldKeychainAccountsIfNeeded()
        let accounts = supportServices.flatMap { service in
            loadAccountIds(for: service.identifier).compactMap { accountId -> ExternalServiceAccountinfo? in
                let mapper: ExternalServiceAccountMapper? = keyChainStore.load(accountKey(service.identifier, accountId))
                return mapper?.account
            }
        }
        
        let activeAccountAndCredentials = accounts
            .compactMap(self.checkActiveAccountInfo(_:))
        
        activeAccountAndCredentials.forEach { info in
            guard case .api(let credential) = info.credential else { return }
            self.remotePool.setup(
                for: info.account.serviceIdentifier,
                accountId: info.accountId,
                credential: credential
            )
        }

        return activeAccountAndCredentials.map { $0.account }
    }
    
    struct ActiveAccountInfo {
        enum Credential {
            case api(APICredential)
            case apple
        }
        let accountId: String
        let account: ExternalServiceAccountinfo
        let credential: Credential
    }
    private func checkActiveAccountInfo(_ account: ExternalServiceAccountinfo) -> ActiveAccountInfo? {
        guard let accountId = account.email else { return nil }
        
        switch account.serviceIdentifier {
        case AppleCalendarService.id:
            guard self.checkAppleCalendarIsNotExpired(accountId)
            else { return nil }
            return .init(
                accountId: accountId, account: account, credential: .apple
            )
            
        default:
            guard let credential = credentialStore.loadCredential(for: account.serviceIdentifier, accountId: accountId)
            else { return nil }
            
            return .init(
                accountId: accountId, account: account, credential: .api(credential)
            )
        }
    }
    
    private func checkAppleCalendarIsNotExpired(
        _ accountId: String
    ) -> Bool {
        
        let hasPermission = self.appleCalendarPermissionChecker.isAuthorized()
        if !hasPermission {
            self.removingAccountAction(AppleCalendarService.id, accountId: accountId)
         }
        return hasPermission
    }

    public func save(
        _ credential: any OAuth2Credential,
        for service: any ExternalCalendarService
    ) async throws -> ExternalServiceAccountinfo {
        switch credential {
        case let google as GoogleOAuth2Credential:
            let apiCredential = APICredential(google: google)
            let accountId = google.email ?? ""
            self.credentialStore.saveCredential(for: service.identifier, accountId: accountId, apiCredential)
            remotePool.setup(for: service.identifier, accountId: accountId, credential: apiCredential)

            let account = ExternalServiceAccountinfo(
                service.identifier, email: google.email
            )
            let mapper = ExternalServiceAccountMapper(account: account)
            self.keyChainStore.update(accountKey(service.identifier, accountId), mapper)
            saveAccountId(accountId, for: service.identifier)
            return account

        case is AppleCalendarCredential:
            // Apple Calendar: OAuth 토큰 없음, Remote pool setup 불필요
            let accountId = AppleCalendarService.localAccountId
            let account = ExternalServiceAccountinfo(service.identifier, email: accountId)
            let mapper = ExternalServiceAccountMapper(account: account)
            self.keyChainStore.update(accountKey(service.identifier, accountId), mapper)
            saveAccountId(accountId, for: service.identifier)
            return account

        default:
            throw RuntimeError("not support credential type")
        }
    }

    public func removeAccount(for serviceIdentifier: String, accountId: String) async throws {
        self.removingAccountAction(serviceIdentifier, accountId: accountId)
    }
    
    private func removingAccountAction(_ serviceIdentifier: String, accountId: String) {
        self.credentialStore.removeCredential(for: serviceIdentifier, accountId: accountId)
        remotePool.remove(for: serviceIdentifier, accountId: accountId)
        self.keyChainStore.remove(accountKey(serviceIdentifier, accountId))
        self.remove(accountId, fromServiceList: serviceIdentifier)
    }
}


private extension APICredential {

    init(google: GoogleOAuth2Credential) {
        self.init(accessToken: google.accessToken)
        self.refreshToken = google.refreshToken
        self.accessTokenExpirationDate = google.accessTokenExpirationDate
        self.refreshTokenExpirationDate = google.refreshTokenExpirationDate
    }
}
