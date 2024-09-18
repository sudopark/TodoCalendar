//
//  AccountUsecase.swift
//  Domain
//
//  Created by sudo.park on 2/25/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


public enum AccountChangedEvent: Sendable {
    case signedIn(Account)
    case signOut
    
    public var isSignIn: Bool {
        guard case .signedIn = self else { return false }
        return true
    }
}

public protocol AccountUsecase: Sendable {
    
    func prepareLastSignInAccount() async throws -> Account?
    
    var currentAccountInfo: AnyPublisher<AccountInfo?, Never> { get }
    var accountStatusChanged: AnyPublisher<AccountChangedEvent, Never> { get }
}
