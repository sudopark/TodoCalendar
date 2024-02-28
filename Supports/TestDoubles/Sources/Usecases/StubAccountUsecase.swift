//
//  StubAccountUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2/29/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions


open class StubAccountUsecase: AccountUsecase, @unchecked Sendable {
    
    private let fakeAccount = CurrentValueSubject<AccountInfo?, Never>(nil)
    
    public init(_ account: AccountInfo? = nil) {
        self.fakeAccount.send(account)
    }
    
    open func prepareLastSignInAccount() async throws -> Account? {
        return nil
    }
    
    open var currentAccountInfo: AnyPublisher<AccountInfo?, Never> {
        return self.fakeAccount
            .eraseToAnyPublisher()
    }
    
    open var accountStatusChanged: AnyPublisher<AccountChangedEvent, Never> {
        return Empty().eraseToAnyPublisher()
    }
}
