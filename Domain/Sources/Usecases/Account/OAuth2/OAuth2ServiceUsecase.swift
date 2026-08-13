//
//  OAuth2ServiceUsecase.swift
//  Domain
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


public protocol OAuth2ServiceUsecase: Sendable {

    associatedtype CredentialType: OAuth2Credential

    @MainActor
    func requestAuthentication() async throws -> CredentialType

    @MainActor
    func requestAuthentication(hint: String?) async throws -> CredentialType

    func handle(open url: URL) -> Bool
}

extension OAuth2ServiceUsecase {

    @MainActor
    public func requestAuthentication(hint: String?) async throws -> CredentialType {
        return try await self.requestAuthentication()
    }
}


public protocol OAuth2ServiceUsecaseProvider: Sendable {

    func usecase(for provider: any OAuth2ServiceProvider) -> (any OAuth2ServiceUsecase)?
    var supportOAuth2Service: [any OAuth2ServiceProvider] { get }
}
