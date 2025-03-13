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
    func saveAuth(_ auth: Auth)
    func removeAuth()
}

public struct AuthStoreImple: AuthStore, APICredentialStore {
    
    private let keyChainStorage: any KeyChainStorage
    private let environmentStorage: any EnvironmentStorage
    public init(
        keyChainStorage: any KeyChainStorage,
        environmentStorage: any EnvironmentStorage
    ) {
        self.keyChainStorage = keyChainStorage
        self.environmentStorage = environmentStorage
    }
    
    private var key: String { "current_auth" }
    private var isLoginKey: String { "isLogIn" }
    
    public func loadCurrentAuth() -> Auth? {
        guard let mapper: AuthMapper = self.keyChainStorage.load(self.key),
              let isLogin: Bool = self.environmentStorage.load(self.isLoginKey),
              isLogin
        else { return nil }
        return mapper.auth
    }
    
    public func loadCredential() -> APICredential? {
        return self.loadCurrentAuth().map { APICredential(auth: $0) }
    }
    
    public func saveAuth(_ auth: Auth) {
        let mapper = AuthMapper(auth: auth)
        self.keyChainStorage.update(self.key, mapper)
        self.environmentStorage.update(self.isLoginKey, true)
    }
    
    public func saveCredential(_ credential: APICredential) {
        self.updateCredential(credential)
    }
    
    public func updateCredential(_ credential: APICredential) {
        guard let currentAuth = self.loadCurrentAuth() else { return }
        let newAuth = Auth(
            uid: currentAuth.uid,
            accessToken: credential.accessToken,
            refreshToken: credential.refreshToken
        )
        let mapper = AuthMapper(auth: newAuth)
        self.keyChainStorage.update(self.key, mapper)
        self.environmentStorage.update(self.isLoginKey, true)
    }
    
    public func removeAuth() {
        self.keyChainStorage.remove(self.key)
        self.environmentStorage.remove(self.isLoginKey)
    }
    
    public func removeCredential() {
        self.removeAuth()
    }
}
