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
    private let spyRemotes: [String: SpyRemote] = [
        GoogleCalendarService(scopes: [.readOnly]).identifier: SpyRemote()
    ]
    private let spyKeyChain = SpyKeyChainStorage()
    
    private func makeReposiotry(
        _ accounts: [(ExternalServiceAccountinfo, APICredential)] = []
    ) -> ExternalCalendarIntegrateRepositoryImple {
        
        accounts.forEach { pair in
            let key = pair.0.serviceIdentifier
            self.spyKeyChain.update("\(key)-account", ExternalServiceAccountMapper(account: pair.0))
            self.spyKeyChain.update("\(key)-credential", APICredentialMapper(credential: pair.1))
        }
        
        return .init(supportServices: self.services, removeAPIPerService: self.spyRemotes, keyChainStore: self.spyKeyChain)
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
    
    // load accounts
    @Test func repository_loadAccounts() async throws {
        // given
        let repository = self.makeReposiotry([(self.dummyGoogleAccount, self.googleCredential)])
        
        // when
        let accounts = try await repository.loadIntegratedAccounts()
        let credentialMap = self.spyRemotes.compactMapValues { $0.credential?.accessToken }
        
        // then
        #expect(accounts.count == 1)
        #expect(accounts.first?.email == "old-email")
        #expect(credentialMap == [
            googleService.identifier: "old-google-access"
        ])
    }
    
    // save credentail
    @Test func repository_saveCredential() async throws {
        // given
        let repository = self.makeReposiotry()
        let accountsBeforeSave = try await repository.loadIntegratedAccounts()
        let credentialBeforeSave: APICredentialMapper? = self.spyKeyChain.load("\(googleService.identifier)-credential")
        let remoteCredentialMapBeforeSave = self.spyRemotes.compactMapValues { $0.credential?.accessToken }
        
        // when
        let googleCredential = GoogleOAuth2Credential(
            idToken: "id", accessToken: "access", refreshToken: "ref"
        ) |> \.email .~ "google"
        let saved = try await repository.save(googleCredential, for: self.googleService)
        let remoteCredentialMapAfterSave = self.spyRemotes.compactMapValues { $0.credential?.accessToken }
        
        let accountsAfterSave = try await repository.loadIntegratedAccounts()
        let credentialAfterSave: APICredentialMapper? = self.spyKeyChain.load("\(googleService.identifier)-credential")
        
        // then
        #expect(accountsBeforeSave.isEmpty == true)
        #expect(saved.email == "google")
        #expect(accountsAfterSave.map { $0.email } == ["google"])
        
        #expect(credentialBeforeSave == nil)
        #expect(credentialAfterSave?.credential.accessToken == "access")
        #expect(credentialAfterSave?.credential.refreshToken == "ref")
        
        #expect(remoteCredentialMapBeforeSave == [:])
        #expect(remoteCredentialMapAfterSave == [
            googleService.identifier: "access"
        ])
    }
    
    // remove account
    @Test func repository_removeAccount() async throws {
        // given
        let repository = self.makeReposiotry([
            (self.dummyGoogleAccount, self.googleCredential)
        ])
        let accountsBeforeSave = try await repository.loadIntegratedAccounts()
        let credentialBeforeSave: APICredentialMapper? = self.spyKeyChain.load("\(googleService.identifier)-credential")
        let remoteCredentialMapBeforeSave = self.spyRemotes.compactMapValues { $0.credential?.accessToken }
        
        // when
        try await repository.removeAccount(for: googleService.identifier)
        let remoteCredentialMapAfterSave = self.spyRemotes.compactMapValues { $0.credential?.accessToken }
        
        let accountsAfterSave = try await repository.loadIntegratedAccounts()
        let credentialAfterSave: APICredentialMapper? = self.spyKeyChain.load("\(googleService.identifier)-credential")
        
        // then
        #expect(accountsBeforeSave.map { $0.email } == ["old-email"])
        #expect(accountsAfterSave.map { $0.email } == [])
        
        #expect(credentialBeforeSave?.credential.accessToken == "old-google-access")
        #expect(credentialAfterSave == nil)
        
        #expect(remoteCredentialMapBeforeSave == [
            googleService.identifier: "old-google-access"
        ])
        #expect(remoteCredentialMapAfterSave == [:])
    }
}


private final class SpyRemote: RemoteAPI, @unchecked Sendable {
    
    func request(_ method: RemoteAPIMethod, _ endpoint: any Endpoint, with header: [String : String]?, parameters: [String : Any]) async throws -> Data {
        throw RuntimeError("failed")
    }
    
    var credential: APICredential?
    func setup(credential: APICredential?) {
        self.credential = credential
    }
    
    func attach(listener: any AutenticatorTokenRefreshListener) { }
}
