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

    public init(
        supportServices: [any ExternalCalendarService],
        remotePool: any ExternalCalendarAccountRemotePool,
        keyChainStore: any KeyChainStorage
    ) {
        self.supportServices = supportServices
        self.remotePool = remotePool
        self.keyChainStore = keyChainStore
        self.credentialStore = .init(keyChainStore: keyChainStore)
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

    private func removeAccountId(_ accountId: String, for serviceId: String) {
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

        accounts.forEach { account in
            guard let accountId = account.email,
                  let credential = credentialStore.loadCredential(for: account.serviceIdentifier, accountId: accountId)
            else { return }
            remotePool.setup(for: account.serviceIdentifier, accountId: accountId, credential: credential)
        }

        return accounts
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

        default:
            throw RuntimeError("not support credential type")
        }
    }

    public func removeAccount(for serviceIdentifier: String, accountId: String) async throws {
        self.credentialStore.removeCredential(for: serviceIdentifier, accountId: accountId)
        remotePool.remove(for: serviceIdentifier, accountId: accountId)
        self.keyChainStore.remove(accountKey(serviceIdentifier, accountId))
        removeAccountId(accountId, for: serviceIdentifier)
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
