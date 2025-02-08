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


// MARK: - ExternalCalendarIntegrationUsecase

public protocol ExternalCalendarIntegrationUsecase: Sendable {
    
    func prepareIntegratedAccounts() async throws
        
    func integrate(external service: any ExternalCalendarService) async throws -> ExternalServiceAccountinfo
    
    func stopIntegrate(external service: any ExternalCalendarService) async throws
    
    func handleAuthenticationResultOrNot(open url: URL) -> Bool
    
    var integratedServiceAccounts: AnyPublisher<[String: ExternalServiceAccountinfo], Never> { get }
}


// MARK: - ExternalCalendarIntegrationUsecaseImple

public final class ExternalCalendarIntegrationUsecaseImple: ExternalCalendarIntegrationUsecase, @unchecked Sendable {
    
    private let oauth2ServiceProvider: any ExternalCalendarOAuthUsecaseProvider
    private let externalServiceIntegrateRepository: any ExternalCalendarIntegrateRepository
    private let sharedDataStore: SharedDataStore
    private var lastestUsedOAuthUsecase: (any OAuth2ServiceUsecase)?
    
    public init(
        oauth2ServiceProvider: any ExternalCalendarOAuthUsecaseProvider,
        externalServiceIntegrateRepository: any ExternalCalendarIntegrateRepository,
        sharedDataStore: SharedDataStore
    ) {
        self.oauth2ServiceProvider = oauth2ServiceProvider
        self.externalServiceIntegrateRepository = externalServiceIntegrateRepository
        self.sharedDataStore = sharedDataStore
    }
}

extension ExternalCalendarIntegrationUsecaseImple {
    
    private var shareKey: String { ShareDataKeys.externalCalendarAccounts.rawValue }
    private typealias AccountsMap = [String: ExternalServiceAccountinfo]
    
    public func prepareIntegratedAccounts() async throws {
        let accounts = try await self.externalServiceIntegrateRepository.loadIntegratedAccounts()
        self.sharedDataStore.put(
            AccountsMap.self, key: self.shareKey,
            accounts.asDictionary { $0.serviceIdentifier }
        )
    }
    
    public func integrate(external service: any ExternalCalendarService) async throws -> ExternalServiceAccountinfo {
        guard let usecase = self.oauth2ServiceProvider.usecase(for: service)
        else {
            throw RuntimeError("not support oauth service for: \(service)")
        }
        self.lastestUsedOAuthUsecase = usecase; defer { self.lastestUsedOAuthUsecase = nil }
        let credential = try await usecase.requestAuthentication()
        let account = try await self.externalServiceIntegrateRepository.save(
            credential, for: service
        )
        self.sharedDataStore.update(AccountsMap.self, key: self.shareKey) { old in
            (old ?? [:]) |> key(service.identifier) .~ account
        }
        return account
    }

    public func stopIntegrate(external service: any ExternalCalendarService) async throws {
        
        try await self.externalServiceIntegrateRepository.removeAccount(
            for: service.identifier
        )
        self.sharedDataStore.update(AccountsMap.self, key: self.shareKey) { old in
            (old ?? [:]) |> key(service.identifier) .~ nil
        }
    }
    
    public func handleAuthenticationResultOrNot(open url: URL) -> Bool {
        if self.lastestUsedOAuthUsecase?.handle(open: url) == true {
            return true
        }
        return false
    }
    
    public var integratedServiceAccounts: AnyPublisher<[String : ExternalServiceAccountinfo], Never> {
        return self.sharedDataStore.observe(AccountsMap.self, key: self.shareKey)
            .map { $0 ?? [:] }
            .eraseToAnyPublisher()
    }
}
