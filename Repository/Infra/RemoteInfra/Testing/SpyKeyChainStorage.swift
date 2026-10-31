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


public class SpyKeyChainStorage: KeyChainStorage, APICredentialStore, @unchecked Sendable {

    public init() { }
    
    private var storage: [String: any Codable] = [:]
    
    public func setupSharedGroup(_ identifier: String) {}
    
    public func load<T>(_ key: String) -> T? where T : Decodable {
        return self.storage[key] as? T
    }
    
    public func update<T>(_ key: String, _ value: T) where T : Encodable {
        self.storage[key] = value as? Codable
    }
    
    private var credentialKey: String { "current_credential" }
    
    public func loadCredential() -> APICredential? {
        let mapper: APICredentialMapper? = self.load(self.credentialKey)
        return mapper?.credential
    }
    
    public func saveCredential(_ credential: APICredential) {
        self.update(self.credentialKey, APICredentialMapper(credential: credential))
    }
    
    public func updateCredential(_ credential: APICredential) {
        guard self.loadCredential() != nil else { return }
        self.saveCredential(credential)
    }
    
    public func remove(_ key: String) {
        self.storage[key] = nil
    }
    
    public func removeCredential() {
        self.remove(self.credentialKey)
    }
}
