//
//  StubExternalCalendarIntegrationUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2/7/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions


open class StubExternalCalendarIntegrationUsecase: ExternalCalendarIntegrationUsecase, @unchecked Sendable {
    
    private let fakeAccountMapSubject = CurrentValueSubject<[String: ExternalServiceAccountinfo], Never>([:])
    
    public init(_ accounts: [ExternalServiceAccountinfo]) {
        self.fakeAccountMapSubject.send(
            accounts.asDictionary { $0.serviceIdentifier }
        )
    }
    
    open func prepareIntegratedAccounts() async throws { }
    
    open func integrate(external service: any ExternalCalendarService) async throws -> ExternalServiceAccountinfo {
        let account = ExternalServiceAccountinfo(service.identifier, email: "email")
        var map = self.fakeAccountMapSubject.value
        map[account.serviceIdentifier] = account
        self.fakeAccountMapSubject.send(map)
        return account
    }
    
    open func stopIntegrate(external service: any ExternalCalendarService) async throws {
        var map = self.fakeAccountMapSubject.value
        map[service.identifier] = nil
        self.fakeAccountMapSubject.send(map)
    }
    
    open func handleAuthenticationResultOrNot(open url: URL) -> Bool {
        return url.absoluteString.starts(with: "https://google.com")
    }
    
    open var integratedServiceAccounts: AnyPublisher<[String : ExternalServiceAccountinfo], Never> {
        return self.fakeAccountMapSubject
            .eraseToAnyPublisher()
    }
}
