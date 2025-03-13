//
//  IntegratedAPICredentialStore.swift
//  Repository
//
//  Created by sudo.park on 1/26/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


public final class IntegratedAPICredentialStore {

    private let keyChainStore: any KeyChainStorage
    public init(keyChainStore: any KeyChainStorage) {
        self.keyChainStore = keyChainStore
    }
    
    private func key(_ identifier: String) -> String {
        return "\(identifier)-credential"
    }
    
    public func loadCredential(for identifier: String) -> APICredential? {
        guard let mapper: APICredentialMapper = self.keyChainStore.load(self.key(identifier))
        else { return nil }
        return mapper.credential
    }
    
    public func saveCredential(for identifier: String, _ credential: APICredential) {
        self.updateCredential(for: identifier, credential)
    }
    
    public func updateCredential(for indentifier: String, _ credential: APICredential) {
        let mapper = APICredentialMapper(credential: credential)
        self.keyChainStore.update(self.key(indentifier), mapper)
    }
    
    public func removeCredential(for identifier: String) {
        self.keyChainStore.remove(self.key(identifier))
    }
}
