//
//  ExternalCalendarIntegrateRepository.swift
//  Domain
//
//  Created by sudo.park on 1/26/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


public protocol ExternalCalendarIntegrateRepository: Sendable {
    
    func loadIntegratedAccounts() async throws -> [ExternalServiceAccountinfo]
    
    func save(
        _ credential: any OAuth2Credential,
        for service: any ExternalCalendarService
    ) async throws -> ExternalServiceAccountinfo
    
    func removeAccount(for serviceIdentifier: String) async throws
}
