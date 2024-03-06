//
//  AuthStore.swift
//  Repository
//
//  Created by sudo.park on 3/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain

public protocol AuthStore: Sendable {
    
    func loadCurrentAuth() -> Auth?
    func updateAuth(_ auth: Auth)
    func removeAuth()
}


extension KeyChainStorageImple: AuthStore {
    
    private var key: String { "current_auth" }
    
    public func loadCurrentAuth() -> Auth? {
        let mapper: AuthMapper? = self.load(self.key)
        return mapper?.auth
    }
    public func updateAuth(_ auth: Auth) {
        let mapper = AuthMapper(auth: auth)
        self.update(self.key, mapper)
    }
    
    public func removeAuth() {
        self.remove(self.key)
    }
}
