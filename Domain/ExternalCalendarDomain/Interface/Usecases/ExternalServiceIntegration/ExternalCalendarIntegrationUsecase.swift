//
//  ExternalCalendarIntegrationUsecase.swift
//  ExternalCalendarDomainInterface
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

    func reauthenticateForWriteScope(
        external service: any ExternalCalendarService, accountId: String
    ) async throws -> ExternalServiceAccountinfo

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

    public func currentOrNewIntegratedAccount(
        for serviceId: String
    ) -> AnyPublisher<ExternalServiceAccountinfo, Never> {
        let currents = Just(self.currentIntegratedAccounts(for: serviceId))
            .flatMap { $0.publisher }
        let newIntegrated = self.integrationStatusChanged
            .compactMap { status -> ExternalServiceAccountinfo? in
                switch status {
                case .integrated(let sid, let account) where sid == serviceId:
                    return account
                default: return nil
                }
            }
        return currents.append(newIntegrated)
            .eraseToAnyPublisher()
    }
}
