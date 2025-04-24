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
    private let remoteAPIPerService: [String: any RemoteAPI]
    private let keyChainStore: any KeyChainStorage
    private let credentialStore: IntegratedAPICredentialStore
    
    public init(
        supportServices: [any ExternalCalendarService],
        removeAPIPerService: [String : any RemoteAPI],
        keyChainStore: any KeyChainStorage
    ) {
        self.supportServices = supportServices
        self.remoteAPIPerService = removeAPIPerService
        self.keyChainStore = keyChainStore
        self.credentialStore = .init(keyChainStore: keyChainStore)
    }
}


extension ExternalCalendarIntegrateRepositoryImple {
    
    private func accountKey(_ identifier: String) -> String {
        return "\(identifier)-account"
    }
    
    public func loadIntegratedAccounts() async throws -> [ExternalServiceAccountinfo] {
        
        let accounts = self.supportServices
            .map { service -> ExternalServiceAccountMapper? in
                return self.keyChainStore.load(self.accountKey(service.identifier))
            }
            .compactMap { $0?.account }
        let accountCredentialMap = accounts
            .asDictionary { $0.serviceIdentifier }
            .compactMapValues { self.credentialStore.loadCredential(for: $0.serviceIdentifier) }
        
        self.supportServices.forEach {
            self.remoteAPIPerService[$0.identifier]?.setup(
                credential: accountCredentialMap[$0.identifier]
            )
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
            self.credentialStore.saveCredential(for: service.identifier, apiCredential)
            self.remoteAPIPerService[service.identifier]?.setup(credential: apiCredential)
            
            let account = ExternalServiceAccountinfo(
                service.identifier, email: google.email
            )
            let mapper = ExternalServiceAccountMapper(account: account)
            self.keyChainStore.update(self.accountKey(service.identifier), mapper)
            return account
            
        default:
            throw RuntimeError("not support credential type")
        }
    }
    
    public func removeAccount(for serviceIdentifier: String) async throws {
        self.credentialStore.removeCredential(for: serviceIdentifier)
        self.remoteAPIPerService[serviceIdentifier]?.setup(credential: nil)
        self.keyChainStore.remove(self.accountKey(serviceIdentifier))
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
