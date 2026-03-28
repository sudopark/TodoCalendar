//
//  ExternalCalendarIntegrationUsecase.swift
//  Domain
//
//  Created by sudo.park on 1/26/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions

// MARK: - ExternalCalendarIntegrationStatus

public enum ExternalCalendarIntegrationStatus: Sendable {
    case integrated(serviceId: String, account: ExternalServiceAccountinfo)
    case disconnected(serviceId: String, accountId: String)

    public var serviceId: String {
        switch self {
        case .integrated(let serviceId, _): return serviceId
        case .disconnected(let serviceId, _): return serviceId
        }
    }
}


// MARK: - ExternalCalendarIntegrationUsecase

public protocol ExternalCalendarIntegrationUsecase: Sendable {
    
    func prepareIntegratedAccounts() async throws
        
    func integrate(external service: any ExternalCalendarService) async throws -> ExternalServiceAccountinfo
    
    func stopIntegrate(external service: any ExternalCalendarService, accountId: String) async throws

    func handleAuthenticationResultOrNot(open url: URL) -> Bool

    var integratedServiceAccounts: AnyPublisher<[String: [ExternalServiceAccountinfo]], Never> { get }
    var integrationStatusChanged: AnyPublisher<ExternalCalendarIntegrationStatus, Never> { get }
    
    func currentIntegratedAccounts() -> [ExternalServiceAccountinfo]
}

extension ExternalCalendarIntegrationUsecase {
    
    public func integrationStatusChanged(for serviceId: String) -> AnyPublisher<ExternalCalendarIntegrationStatus, Never> {
        return self.integrationStatusChanged
            .filter { $0.serviceId == serviceId }
            .eraseToAnyPublisher()
    }
    
    public func currentIntegratedAccounts(for serviceId: String) -> [ExternalServiceAccountinfo] {
        return self.currentIntegratedAccounts().filter { $0.serviceIdentifier == serviceId }
    }
}


// MARK: - ExternalCalendarIntegrationUsecaseImple

public final class ExternalCalendarIntegrationUsecaseImple: ExternalCalendarIntegrationUsecase, @unchecked Sendable {
    
    private let oauth2ServiceProvider: any ExternalCalendarOAuthUsecaseProvider
    private let externalServiceIntegrateRepository: any ExternalCalendarIntegrateRepository
    private let dbConnectionController: any ExternalCalendarDBConnectionControl
    private let sharedDataStore: SharedDataStore
    private var lastestUsedOAuthUsecase: (any OAuth2ServiceUsecase)?
    
    private let integrationStatusChangedSubject = PassthroughSubject<ExternalCalendarIntegrationStatus, Never>()
    
    public init(
        oauth2ServiceProvider: any ExternalCalendarOAuthUsecaseProvider,
        externalServiceIntegrateRepository: any ExternalCalendarIntegrateRepository,
        dbConnectionController: any ExternalCalendarDBConnectionControl,
        sharedDataStore: SharedDataStore
    ) {
        self.oauth2ServiceProvider = oauth2ServiceProvider
        self.externalServiceIntegrateRepository = externalServiceIntegrateRepository
        self.dbConnectionController = dbConnectionController
        self.sharedDataStore = sharedDataStore
    }
}

extension ExternalCalendarIntegrationUsecaseImple {
    
    private var shareKey: String { ShareDataKeys.externalCalendarAccounts.rawValue }
    private typealias AccountsMap = [String: [ExternalServiceAccountinfo]]

    public func prepareIntegratedAccounts() async throws {
        let accounts = try await self.externalServiceIntegrateRepository.loadIntegratedAccounts()
        let accountsMap = accounts.reduce(into: AccountsMap()) { map, account in
            map[account.serviceIdentifier, default: []].append(account)
        }
        self.sharedDataStore.put(AccountsMap.self, key: self.shareKey, accountsMap)
        await accounts.asyncForEach { account in
            try? await self.dbConnectionController.open(serviceId: account.serviceIdentifier)
        }
    }

    public func integrate(external service: any ExternalCalendarService) async throws -> ExternalServiceAccountinfo {
        guard let usecase = self.oauth2ServiceProvider.usecase(for: service)
        else {
            throw RuntimeError("not support oauth service for: \(service)")
        }
        self.lastestUsedOAuthUsecase = usecase; defer { self.lastestUsedOAuthUsecase = nil }
        let credential = try await usecase.requestAuthentication()
        let account = try await self.externalServiceIntegrateRepository.save(credential, for: service)
            |> \.intergrationTime .~ Date()
        try? await self.dbConnectionController.open(serviceId: service.identifier)
        self.sharedDataStore.update(AccountsMap.self, key: self.shareKey) { old in
            var map = old ?? [:]
            map[service.identifier, default: []].removeAll { $0.email == account.email }
            map[service.identifier, default: []].append(account)
            return map
        }
        self.integrationStatusChangedSubject.send(
            .integrated(serviceId: service.identifier, account: account)
        )
        return account
    }

    public func stopIntegrate(external service: any ExternalCalendarService, accountId: String) async throws {
        try await self.externalServiceIntegrateRepository.removeAccount(
            for: service.identifier, accountId: accountId
        )
        self.sharedDataStore.update(AccountsMap.self, key: self.shareKey) { old in
            var map = old ?? [:]
            map[service.identifier]?.removeAll { $0.email == accountId }
            return map
        }
        try? await self.dbConnectionController.close(serviceId: service.identifier)
        self.integrationStatusChangedSubject.send(
            .disconnected(serviceId: service.identifier, accountId: accountId)
        )
    }

    public func handleAuthenticationResultOrNot(open url: URL) -> Bool {
        if self.lastestUsedOAuthUsecase?.handle(open: url) == true {
            return true
        }
        return false
    }

    public var integratedServiceAccounts: AnyPublisher<[String: [ExternalServiceAccountinfo]], Never> {
        return self.sharedDataStore.observe(AccountsMap.self, key: self.shareKey)
            .map { $0 ?? [:] }
            .eraseToAnyPublisher()
    }
    
    public var integrationStatusChanged: AnyPublisher<ExternalCalendarIntegrationStatus, Never> {
        return self.integrationStatusChangedSubject
            .eraseToAnyPublisher()
    }
    
    public func currentIntegratedAccounts() -> [ExternalServiceAccountinfo] {
        let accountMap = self.sharedDataStore.value(AccountsMap.self, key: self.shareKey) ?? [:]
        return accountMap.values.flatMap { $0 }
    }
}
