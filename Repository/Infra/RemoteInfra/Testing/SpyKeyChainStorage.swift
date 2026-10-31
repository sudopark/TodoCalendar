//
//  SpyKeyChainStorage.swift
//  RemoteInfraTesting
//
//  Created by sudo.park on 10/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import StorageInfraInterface
import RemoteInfraInterface
import RemoteInfra
import AccountDomainInterface


public class SpyKeyChainStorage: KeyChainStorage, AuthStore, APICredentialStore, @unchecked Sendable {

    public init() { }
    
    public func loadCredential() -> APICredential? {
        nil
    }
    
    public func saveCredential(_ credential: APICredential) {
        
    }
    
    private var storage: [String: any Codable] = [:]
    
    public func setupSharedGroup(_ identifier: String) {}
    
    public func load<T>(_ key: String) -> T? where T : Decodable {
        return self.storage[key] as? T
    }
    
    public func loadCurrentAuth() -> AccountDomainInterface.Auth? {
        let mapper: AuthMapper? = self.load("current_auth")
        return mapper?.auth
    }
    
    public func saveAuth(_ auth: AccountDomainInterface.Auth) {
        let mapper = AuthMapper(auth: auth)
        self.update("current_auth", mapper)
    }
    
    public func update<T>(_ key: String, _ value: T) where T : Encodable {
        self.storage[key] = value as? Codable
    }
    
    public func updateCredential(_ credential: APICredential) {
        guard let auth = self.loadCurrentAuth() else { return }
        let newAuth = Auth(
            uid: auth.uid,
            accessToken: credential.accessToken,
            refreshToken: credential.refreshToken
        )
        self.saveAuth(newAuth)
    }
    
    public func remove(_ key: String) {
        self.storage[key] = nil
    }
    
    public func removeAuth() {
        self.storage.removeValue(forKey: "current_auth")
    }
    
    public func removeCredential() {
        self.removeAuth()
    }
}
