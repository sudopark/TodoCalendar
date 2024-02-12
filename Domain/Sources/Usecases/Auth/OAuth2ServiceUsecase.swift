//
//  OAuth2ServiceUsecase.swift
//  Domain
//
//  Created by sudo.park on 2/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


public protocol OAuth2ServiceUsecase: Sendable {
    
    var provider: any OAuth2ServiceProvider { get }
    
    func signIn() async throws -> any OAuth2Credential
}


public protocol OAuth2ServiceUsecaseProvider: Sendable {
    
    func usecase(for provider: any OAuth2ServiceProvider) -> (any OAuth2ServiceUsecase)?
}

//public struct OAuth2ServiceUsecaseProviderImple: OAuth2ServiceUsecaseProvider {
//    
//    private let
//}
