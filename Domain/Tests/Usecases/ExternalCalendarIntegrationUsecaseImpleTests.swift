//
//  ExternalCalendarIntegrationUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 1/27/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit

@testable import Domain


final class ExternalCalendarIntegrationUsecaseImpleTests: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = []
    
    private func makeUsecase(
        startWithIntegrated accounts: [ExternalServiceAccountinfo] = [],
        withWait subject: PassthroughSubject<Void, Never>? = nil
    ) -> ExternalCalendarIntegrationUsecaseImple {
        
        let serviceProvider = FakeOauth2ServiceProvider()
        serviceProvider.authenticationWaitMocking = subject
        let repository = StubExternalCalendarIntegrateRepository(accounts)
        let store = SharedDataStore()
        
        return ExternalCalendarIntegrationUsecaseImple(
            oauth2ServiceProvider: serviceProvider,
            externalServiceIntegrateRepository: repository,
            sharedDataStore: store
        )
    }
}

extension ExternalCalendarIntegrationUsecaseImpleTests {
    
    func usecase_prepareAccounts() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let result: Void? = try await usecase.prepareIntegratedAccounts()
        
        // then
        #expect(result != nil)
    }
    
    @Test("연동된 account 준비 이후 account map 업데이트", arguments: [[], [ExternalServiceAccountinfo("google", email: "email")]])
    func usecase_whenAfterPrepareAccounts_updateSharedAccountsMap(
        _ integratedAccounts: [ExternalServiceAccountinfo]
    ) async throws {
        // given
        let confirmation = self.expectConfirm("wait account map updated")
        confirmation.count = 2
        confirmation.timeout = .milliseconds(10)
        let usecase = self.makeUsecase(startWithIntegrated: integratedAccounts)
        
        // when
        let accountMaps = try await self.outputs(confirmation, for: usecase.integratedServiceAccounts) {
            
            try await usecase.prepareIntegratedAccounts()
        }
        
        // then
        let identifiers = accountMaps.map { $0.keys }.map { $0.sorted() }
        #expect(identifiers == [
            [], integratedAccounts.map { $0.serviceIdentifier }
        ])
        let accounts = accountMaps.flatMap { $0.values }
        let withoutIntegrationTime = accounts.map { $0.intergrationTime }.reduce(true) { $0 && ($1 == nil) }
        #expect(withoutIntegrationTime == true)
    }
    
    // integrate
    @Test func usecase_integrateService() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let service = GoogleCalendarService(scopes: [.readOnly])
        let account = try await usecase.integrate(external: service)
        
        // then
        #expect(account.serviceIdentifier == service.identifier)
        #expect(account.email == "google@email.com")
        #expect(account.intergrationTime != nil)
    }
    
    // not support servie integrate => error
    @Test func usecase_integrateNotSupportService_fail() async {
        // given
        struct DummyService: ExternalCalendarService {
            let identifier: String = "not_support"
        }
        let usecase = self.makeUsecase()
        
        // when
        let service = DummyService()
        let account = try? await usecase.integrate(external: service)
        
        // then
        #expect(account == nil)
    }
    
    // after integrate -> update integrated accounts map
    @Test func usecase_whenAfterIntegrate_updateSharedAccountMap() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readOnly])
        let confirmation = self.expectConfirm("연동 이후 연동된 계정리스트 업데이트")
        confirmation.count = 2
        let usecase = self.makeUsecase()
        
        // when
        let accountMaps = try await self.outputs(confirmation, for: usecase.integratedServiceAccounts) {
            _ = try await usecase.integrate(external: service)
        }
        
        // then
        let identifiers = accountMaps.map { $0.keys }.map { $0.sorted() }
        #expect(identifiers == [
            [], [service.identifier]
        ])
    }
    
    // stop integrate
    @Test func usecase_stopIntegrate() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readOnly])
        let account = ExternalServiceAccountinfo(service.identifier, email: "some")
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()
        
        // when
        let result: Void? = try await usecase.stopIntegrate(external: service)
        
        // then
        #expect(result != nil)
    }
    
    // stop integrate -> update integrated accounts map
    @Test func usecase_whenAfterStopIntegrate_updateSharedAccountMap() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readOnly])
        let account = ExternalServiceAccountinfo(service.identifier, email: "some")
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()
        let confirm = self.expectConfirm("연동 해제 이후 연동된 계정리스트 업데이트")
        confirm.count = 2
        
        // when
        let accountMaps = try await self.outputs(confirm, for: usecase.integratedServiceAccounts) {
            try await usecase.stopIntegrate(external: service)
        }
        
        // then
        let identifiers = accountMaps.map { $0.keys }.map { $0.sorted() }
        #expect(identifiers == [
            [service.identifier], []
        ])
    }
    
    @Test func usecase_handleAuthenticationResult() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readOnly])
        let wait = PassthroughSubject<Void, Never>()
        let usecase = self.makeUsecase(withWait: wait)
        var handled: Bool?
        
        // when
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            let url = URL(string: "https://google.com")
            handled = usecase.handleAuthenticationResultOrNot(open: url!)
            wait.send(())
        }
        let _ = try await usecase.integrate(external: service)
        // then
        #expect(handled == true)
    }
    
    @Test func usecase_whenNotIntegrating_notHandleAuthenticationResult() {
        // given
        let service = GoogleCalendarService(scopes: [.readOnly])
        let usecase = self.makeUsecase()
        
        // when
        let url = URL(string: "https://google.com")
        let handled = usecase.handleAuthenticationResultOrNot(open: url!)
        
        // then
        #expect(handled == false)
    }
    
    @Test func usecase_whenServiceIntegrationStatusChanged_notify() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readOnly])
        let expect = self.expectConfirm("연동여부 변경시에 외부에 전파")
        expect.count = 2
        let usecase = self.makeUsecase()
        
        // when
        let statues = try await self.outputs(expect, for: usecase.integrationStatusChanged) {
            
            _ = try await usecase.integrate(external: service)
            try await usecase.stopIntegrate(external: service)
        }
        
        // then
        let services = statues.map { $0.serviceId }
        let isIntegrated = statues.map { $0.isIntegrated }
        #expect(services == [service.identifier, service.identifier])
        #expect(isIntegrated == [true, false])
    }
}


private final class StubGoogleOAuth2ServiceUsecase: OAuth2ServiceUsecase, @unchecked Sendable {
    
    typealias CredentialType = GoogleOAuth2Credential
    
    var authenticationWaitMocking: PassthroughSubject<Void, Never>?
    func requestAuthentication() async throws -> GoogleOAuth2Credential {
        
        let makeCredential: () -> GoogleOAuth2Credential = {
            return .init(idToken: "id", accessToken: "access", refreshToken: "refresh")
                |> \.email .~ "google@email.com"
        }
        if let mocking = self.authenticationWaitMocking {
            let _ = try await mocking.firstValue(with: 100)
            return makeCredential()
        }
        return makeCredential()
    }
    
    func handle(open url: URL) -> Bool {
        if url.absoluteString.starts(with: "https://google") {
            return true
        }
        return false
    }
}

private final class FakeOauth2ServiceProvider: ExternalCalendarOAuthUsecaseProvider, @unchecked Sendable {
    
    var authenticationWaitMocking: PassthroughSubject<Void, Never>?
    
    func usecase(for service: any ExternalCalendarService) -> (any OAuth2ServiceUsecase)? {
        switch service {
        case is GoogleCalendarService:
            return StubGoogleOAuth2ServiceUsecase()
                |> \.authenticationWaitMocking .~ authenticationWaitMocking
            
        default: return nil
        }
    }
}


private final class StubExternalCalendarIntegrateRepository: ExternalCalendarIntegrateRepository, @unchecked Sendable {
    
    private var accountMap: [String: ExternalServiceAccountinfo] = [:]
    
    init(_ accounts: [ExternalServiceAccountinfo]) {
        self.accountMap = accounts.asDictionary { $0.serviceIdentifier }
    }
    
    func loadIntegratedAccounts() async throws -> [ExternalServiceAccountinfo] {
        return Array(self.accountMap.values)
    }
    
    func save(
        _ credential: any OAuth2Credential,
        for service: any ExternalCalendarService
    ) async throws -> ExternalServiceAccountinfo {
        switch credential {
        case let google as GoogleOAuth2Credential:
            let account = ExternalServiceAccountinfo(service.identifier, email: google.email)
            self.accountMap[service.identifier] = account
            return account
            
        default:
            throw RuntimeError("failed")
        }
    }
    
    func removeAccount(for serviceIdentifier: String) async throws {
        self.accountMap[serviceIdentifier] = nil
    }
}
