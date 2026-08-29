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
    fileprivate let spyConnectionController = SpyExternalCalendarDBConnectionController()
    fileprivate let fakeOauthProvider = FakeOauth2ServiceProvider()

    private func makeUsecase(
        startWithIntegrated accounts: [ExternalServiceAccountinfo] = [],
        withWait subject: PassthroughSubject<Void, Never>? = nil
    ) -> ExternalCalendarIntegrationUsecaseImple {

        fakeOauthProvider.authenticationWaitMocking = subject
        let repository = StubExternalCalendarIntegrateRepository(accounts)
        let store = SharedDataStore()

        return ExternalCalendarIntegrationUsecaseImple(
            oauth2ServiceProvider: fakeOauthProvider,
            externalServiceIntegrateRepository: repository,
            dbConnectionController: spyConnectionController,
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
        let accounts = accountMaps.flatMap { $0.values }.flatMap { $0 }
        let withoutIntegrationTime = accounts.map { $0.intergrationTime }.reduce(true) { $0 && ($1 == nil) }
        #expect(withoutIntegrationTime == true)
    }
    
    // integrate
    @Test func usecase_integrateService() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let service = GoogleCalendarService(scopes: [.readWrite])
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
            let isSingleAccountService: Bool = false
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
        let service = GoogleCalendarService(scopes: [.readWrite])
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
        let service = GoogleCalendarService(scopes: [.readWrite])
        let account = ExternalServiceAccountinfo(service.identifier, email: "some")
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()
        
        // when
        let result: Void? = try await usecase.stopIntegrate(external: service, accountId: "some")

        // then
        #expect(result != nil)
    }
    
    // stop integrate -> update integrated accounts map
    @Test func usecase_whenAfterStopIntegrate_updateSharedAccountMap() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readWrite])
        let account = ExternalServiceAccountinfo(service.identifier, email: "some")
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()
        let confirm = self.expectConfirm("연동 해제 이후 연동된 계정리스트 업데이트")
        confirm.count = 2
        
        // when
        let accountMaps = try await self.outputs(confirm, for: usecase.integratedServiceAccounts) {
            try await usecase.stopIntegrate(external: service, accountId: "some")
        }
        
        // then
        let accountCounts = accountMaps.map { map in
            map[service.identifier]?.count ?? 0
        }
        #expect(accountCounts == [1, 0])
    }
    
    @Test func usecase_handleAuthenticationResult() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readWrite])
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
        let service = GoogleCalendarService(scopes: [.readWrite])
        let usecase = self.makeUsecase()
        
        // when
        let url = URL(string: "https://google.com")
        let handled = usecase.handleAuthenticationResultOrNot(open: url!)
        
        // then
        #expect(handled == false)
    }
    
    // prepareIntegratedAccounts 시에 이미 연동된 서비스 DB open
    @Test func usecase_whenPrepareAccounts_openDBForIntegratedServices() async throws {
        // given
        let account = ExternalServiceAccountinfo("google", email: "email")
        let usecase = self.makeUsecase(startWithIntegrated: [account])

        // when
        try await usecase.prepareIntegratedAccounts()

        // then
        #expect(spyConnectionController.didOpenedServiceIds == ["google"])
    }

    // integrate 시에 DB open
    @Test func usecase_whenIntegrate_openDB() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readWrite])
        let usecase = self.makeUsecase()

        // when
        _ = try await usecase.integrate(external: service)

        // then
        #expect(spyConnectionController.didOpenedServiceIds == [service.identifier])
    }

    // stopIntegrate 시에 DB close
    @Test func usecase_whenStopIntegrate_closeDB() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readWrite])
        let account = ExternalServiceAccountinfo(service.identifier, email: "some")
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()

        // when
        try await usecase.stopIntegrate(external: service, accountId: "some")

        // then
        #expect(spyConnectionController.didClosedServiceIds == [service.identifier])
    }

    @Test func usecase_whenServiceIntegrationStatusChanged_notify() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readWrite])
        let expect = self.expectConfirm("연동여부 변경시에 외부에 전파")
        expect.count = 2
        let usecase = self.makeUsecase()
        
        // when
        let statues = try await self.outputs(expect, for: usecase.integrationStatusChanged) {
            
            _ = try await usecase.integrate(external: service)
            try await usecase.stopIntegrate(external: service, accountId: "google@email.com")
        }
        
        // then
        let services = statues.map { $0.serviceId }
        #expect(services == [service.identifier, service.identifier])
        if case .integrated(_, let account) = statues[0] {
            #expect(account.email == "google@email.com")
        } else {
            Issue.record("첫번째 상태는 integrated 이어야 함")
        }
        if case .disconnected(_, let accountId) = statues[1] {
            #expect(accountId == "google@email.com")
        } else {
            Issue.record("두번째 상태는 disconnected 이어야 함")
        }
    }

    @Test func usecase_currentIntegratedAccounts() async throws {
        // given
        let account = ExternalServiceAccountinfo("google", email: "email")
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()

        // when
        let accounts = usecase.currentIntegratedAccounts()

        // then
        #expect(accounts.count == 1)
        #expect(accounts.first?.email == "email")
    }

    @Test func usecase_currentIntegratedAccountsForService() async throws {
        // given
        let google = ExternalServiceAccountinfo("google", email: "google@email.com")
        let other = ExternalServiceAccountinfo("other", email: "other@email.com")
        let usecase = self.makeUsecase(startWithIntegrated: [google, other])
        try await usecase.prepareIntegratedAccounts()

        // when
        let accounts = usecase.currentIntegratedAccounts(for: "google")

        // then
        #expect(accounts.count == 1)
        #expect(accounts.first?.email == "google@email.com")
    }

    // Apple Calendar integrate 성공
    @Test func usecase_integrateAppleCalendar_succeed() async throws {
        // given
        let usecase = self.makeUsecase()

        // when
        let service = AppleCalendarService()
        let account = try await usecase.integrate(external: service)

        // then
        #expect(account.serviceIdentifier == service.identifier)
        #expect(account.email == AppleCalendarService.localAccountId)
    }

    // reauthenticateForWriteScope — 계정 힌트 전달 + 결과 계정 동일성 검증 + write scope 부여 검증
    @Test func usecase_reauthenticateForWriteScope_succeed_updatesGrantedScopes() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readWrite])
        let account = ExternalServiceAccountinfo(service.identifier, email: "google@email.com")
        self.fakeOauthProvider.stubGoogleGrantedScopes = [GoogleCalendarService.Scope.readWrite.rawValue]
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()

        // when
        let reauthenticated = try await usecase.reauthenticateForWriteScope(external: service, accountId: "google@email.com")

        // then
        #expect(reauthenticated.email == "google@email.com")
        #expect(reauthenticated.grantedScopes == [GoogleCalendarService.Scope.readWrite.rawValue])
        let stored = usecase.currentIntegratedAccounts(for: service.identifier).first
        #expect(stored?.grantedScopes == [GoogleCalendarService.Scope.readWrite.rawValue])
    }

    @Test func usecase_reauthenticateForWriteScope_passesAccountIdAsOAuthHint() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readWrite])
        let account = ExternalServiceAccountinfo(service.identifier, email: "google@email.com")
        self.fakeOauthProvider.stubGoogleGrantedScopes = [GoogleCalendarService.Scope.readWrite.rawValue]
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()

        // when
        _ = try await usecase.reauthenticateForWriteScope(external: service, accountId: "google@email.com")

        // then
        #expect(self.fakeOauthProvider.latestGoogleUsecase?.didRequestAuthenticationWithHint == "google@email.com")
    }

    @Test func usecase_reauthenticateForWriteScope_whenResultAccountMismatches_throws() async throws {
        // given — 재인증 결과가 다른 계정으로 로그인됨. write scope 는 정상 승인돼 있어
        // 계정 동일성 검증이 write scope 검증보다 먼저 실행돼야만 이 케이스가 던진다
        let service = GoogleCalendarService(scopes: [.readWrite])
        let account = ExternalServiceAccountinfo(service.identifier, email: "google@email.com")
        self.fakeOauthProvider.stubGoogleEmail = "other@email.com"
        self.fakeOauthProvider.stubGoogleGrantedScopes = [GoogleCalendarService.Scope.readWrite.rawValue]
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()

        // when
        do {
            _ = try await usecase.reauthenticateForWriteScope(external: service, accountId: "google@email.com")
            Issue.record("계정 불일치로 실패해야 함")
        } catch is GoogleCalendarWriteScopeFailReason {
            Issue.record("write scope 검증이 아니라 계정 동일성 검증에서 실패해야 함")
        } catch {
            // then — GoogleCalendarWriteScopeFailReason 이 아닌 다른 에러(RuntimeError)로 실패
        }
    }

    @Test func usecase_reauthenticateForWriteScope_doesNotDuplicateAccount() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readWrite])
        let account = ExternalServiceAccountinfo(service.identifier, email: "google@email.com")
        self.fakeOauthProvider.stubGoogleGrantedScopes = [GoogleCalendarService.Scope.readWrite.rawValue]
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()

        // when
        _ = try await usecase.reauthenticateForWriteScope(external: service, accountId: "google@email.com")

        // then — 같은 이메일이므로 교체일 뿐 계정이 늘어나지 않는다
        let accounts = usecase.currentIntegratedAccounts(for: service.identifier)
        #expect(accounts.count == 1)
    }

    // 서비스에 주입된 scope 와 무관하게 항상 write scope 로 승격 재인증을 요청한다
    @Test func usecase_reauthenticateForWriteScope_requestsWriteScopeRegardlessOfServiceScopes() async throws {
        // given — readonly 로 만든 서비스를 넘긴다
        let readonlyService = GoogleCalendarService(scopes: [.readonly])
        let account = ExternalServiceAccountinfo(readonlyService.identifier, email: "google@email.com")
        self.fakeOauthProvider.stubGoogleGrantedScopes = [GoogleCalendarService.Scope.readWrite.rawValue]
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()

        // when
        _ = try await usecase.reauthenticateForWriteScope(external: readonlyService, accountId: "google@email.com")

        // then — provider 가 실제로 받은 서비스의 scopes 는 write 다
        #expect(self.fakeOauthProvider.didRequestUsecaseForGoogleService?.scopes == [.readWrite])
    }

    @Test func usecase_reauthenticateForWriteScope_whenWriteScopeNotGranted_throwsNotGranted() async throws {
        // given — write 를 요청했지만 readonly 만 승인됨
        let service = GoogleCalendarService(scopes: [.readWrite])
        let account = ExternalServiceAccountinfo(service.identifier, email: "google@email.com")
        self.fakeOauthProvider.stubGoogleGrantedScopes = [GoogleCalendarService.Scope.readonly.rawValue]
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()

        // when
        do {
            _ = try await usecase.reauthenticateForWriteScope(external: service, accountId: "google@email.com")
            Issue.record("notGranted 로 실패해야 함")
        } catch is GoogleCalendarWriteScopeFailReason {
            // then — expected
        } catch {
            Issue.record("GoogleCalendarWriteScopeFailReason 이어야 하는데: \(error)")
        }
    }

    @Test func usecase_reauthenticateForWriteScope_whenGrantedScopesIsNil_throwsNotGranted() async throws {
        // given — grantedScopes 가 nil (fail-closed)
        let service = GoogleCalendarService(scopes: [.readWrite])
        let account = ExternalServiceAccountinfo(service.identifier, email: "google@email.com")
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()

        // when
        do {
            _ = try await usecase.reauthenticateForWriteScope(external: service, accountId: "google@email.com")
            Issue.record("notGranted 로 실패해야 함")
        } catch is GoogleCalendarWriteScopeFailReason {
            // then — expected
        } catch {
            Issue.record("GoogleCalendarWriteScopeFailReason 이어야 하는데: \(error)")
        }
    }

    // 애플처럼 scope 개념이 없는 서비스는 write scope 승격 대상에서 제외한다
    @Test func usecase_reauthenticateForWriteScope_forNonGoogleService_doesNotRequestGoogleScope() async throws {
        // given — 계정 동일성 검증은 구글 자격증명만 다루므로 호출 자체는 실패하지만, 여기서 보는 건 provider 승격 여부다
        let service = AppleCalendarService()
        let usecase = self.makeUsecase()

        // when
        _ = try? await usecase.reauthenticateForWriteScope(
            external: service, accountId: AppleCalendarService.localAccountId
        )

        // then
        #expect(self.fakeOauthProvider.didRequestUsecaseForGoogleService == nil)
    }

    // 승격은 신규 연동이 아니라 기존 계정의 자격증명 교체이므로 .integrated 를 재방출하지 않는다
    @Test func usecase_reauthenticateForWriteScope_doesNotBroadcastIntegratedStatus() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readWrite])
        let account = ExternalServiceAccountinfo(service.identifier, email: "google@email.com")
        self.fakeOauthProvider.stubGoogleGrantedScopes = [GoogleCalendarService.Scope.readWrite.rawValue]
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()
        let confirm = self.expectConfirm("승격은 integrationStatusChanged 를 방출하지 않는다")
        confirm.count = 0
        confirm.timeout = .milliseconds(200)

        // when
        let statuses = try await self.outputs(confirm, for: usecase.integrationStatusChanged) {
            _ = try await usecase.reauthenticateForWriteScope(external: service, accountId: "google@email.com")
        }

        // then
        #expect(statuses.isEmpty)
    }

    // dbConnectionController.open 은 호출마다 refcount +1 이라, 승격에서 재호출하면 대응 close 없이 카운트만 누적된다
    @Test func usecase_reauthenticateForWriteScope_doesNotReopenDBConnection() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readWrite])
        let account = ExternalServiceAccountinfo(service.identifier, email: "google@email.com")
        self.fakeOauthProvider.stubGoogleGrantedScopes = [GoogleCalendarService.Scope.readWrite.rawValue]
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()
        let openCountBeforeReauth = self.spyConnectionController.didOpenedServiceIds.count

        // when
        _ = try await usecase.reauthenticateForWriteScope(external: service, accountId: "google@email.com")

        // then
        #expect(self.spyConnectionController.didOpenedServiceIds.count == openCountBeforeReauth)
    }

    @Test func currentOrNewIntegratedAccount_whenAlreadyIntegrated_emitsCurrentThenStops() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readWrite])
        let account = ExternalServiceAccountinfo(service.identifier, email: "google@email.com")
        let usecase = self.makeUsecase(startWithIntegrated: [account])
        try await usecase.prepareIntegratedAccounts()

        // when
        var emitted: [ExternalServiceAccountinfo] = []
        let sub = usecase.currentOrNewIntegratedAccount(for: service.identifier)
            .sink { emitted.append($0) }
        try await Task.sleep(for: .milliseconds(100))
        sub.cancel()

        // then — 현재 연동 계정 1회만 방출, 중복 없음
        #expect(emitted.count == 1)
        #expect(emitted.first?.email == "google@email.com")
    }

    @Test func currentOrNewIntegratedAccount_whenNewIntegration_emitsOnceWithoutDuplicate() async throws {
        // given
        let service = GoogleCalendarService(scopes: [.readWrite])
        let usecase = self.makeUsecase()
        let expect = self.expectConfirm("신규 연동 시 계정 1회만 방출")

        // when
        let accounts = try await self.outputs(expect, for: usecase.currentOrNewIntegratedAccount(for: service.identifier)) {
            _ = try await usecase.integrate(external: service)
        }
        try await Task.sleep(for: .milliseconds(100))

        // then — 신규 연동 계정 1회만 방출, integratedServiceAccounts 업데이트에 의한 중복 없음
        #expect(accounts.count == 1)
        #expect(accounts.first?.email == "google@email.com")
    }
}


private final class SpyExternalCalendarDBConnectionController: ExternalCalendarDBConnectionControl, @unchecked Sendable {

    var didOpenedServiceIds: [String] = []
    var didClosedServiceIds: [String] = []

    func open(serviceId: String) async throws {
        self.didOpenedServiceIds.append(serviceId)
    }

    func close(serviceId: String) async throws {
        self.didClosedServiceIds.append(serviceId)
    }
}


private final class StubGoogleOAuth2ServiceUsecase: OAuth2ServiceUsecase, @unchecked Sendable {

    typealias CredentialType = GoogleOAuth2Credential

    var authenticationWaitMocking: PassthroughSubject<Void, Never>?
    private let stubEmail: String
    private let stubGrantedScopes: [String]?
    private(set) var didRequestAuthenticationWithHint: String?

    init(email: String = "google@email.com", grantedScopes: [String]? = nil) {
        self.stubEmail = email
        self.stubGrantedScopes = grantedScopes
    }

    func requestAuthentication() async throws -> GoogleOAuth2Credential {
        return try await self.requestAuthentication(hint: nil)
    }

    func requestAuthentication(hint: String?) async throws -> GoogleOAuth2Credential {
        self.didRequestAuthenticationWithHint = hint

        let makeCredential: () -> GoogleOAuth2Credential = { [stubEmail, stubGrantedScopes] in
            return .init(idToken: "id", accessToken: "access", refreshToken: "refresh")
                |> \.email .~ stubEmail
                |> \.grantedScopes .~ stubGrantedScopes
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
    var stubGoogleEmail: String = "google@email.com"
    var stubGoogleGrantedScopes: [String]?
    private(set) var latestGoogleUsecase: StubGoogleOAuth2ServiceUsecase?
    private(set) var didRequestUsecaseForGoogleService: GoogleCalendarService?

    func usecase(for service: any ExternalCalendarService) -> (any OAuth2ServiceUsecase)? {
        switch service {
        case let google as GoogleCalendarService:
            self.didRequestUsecaseForGoogleService = google
            let usecase = StubGoogleOAuth2ServiceUsecase(email: stubGoogleEmail, grantedScopes: stubGoogleGrantedScopes)
                |> \.authenticationWaitMocking .~ authenticationWaitMocking
            self.latestGoogleUsecase = usecase
            return usecase

        case is AppleCalendarService:
            return StubAppleCalendarOAuth2ServiceUsecase()

        default: return nil
        }
    }
}


private final class StubAppleCalendarOAuth2ServiceUsecase: OAuth2ServiceUsecase, @unchecked Sendable {
    typealias CredentialType = AppleCalendarCredential
    func requestAuthentication() async throws -> AppleCalendarCredential { .init() }
    func handle(open url: URL) -> Bool { false }
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
                |> \.grantedScopes .~ google.grantedScopes
            self.accountMap[service.identifier] = account
            return account

        case is AppleCalendarCredential:
            let account = ExternalServiceAccountinfo(service.identifier, email: AppleCalendarService.localAccountId)
            self.accountMap[service.identifier] = account
            return account

        default:
            throw RuntimeError("failed")
        }
    }

    func removeAccount(for serviceIdentifier: String, accountId: String) async throws {
        self.accountMap[serviceIdentifier] = nil
    }
}
