//
//  GoogleAPICredentialStore.swift
//  Repository
//
//  Created by sudo.park on 1/22/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - GoogleAPICredentialStore

public protocol GoogleAPICredentialStore: APICredentialStore {
    
    func loadCredential() -> APICredential?
    func saveCredential(_ credential: APICredential)
}

public final class GoogleAPICredentialStoreImple: GoogleAPICredentialStore {
    
    private let keyChainStore: any KeyChainStorage
    public init(keyChainStore: any KeyChainStorage) {
        self.keyChainStore = keyChainStore
    }
    
    private var key: String { "google_api_token" }
}

extension GoogleAPICredentialStoreImple {
    
    public func loadCredential() -> APICredential? {
        guard let mapper: APICredentialMapper = self.keyChainStore.load(self.key)
        else { return nil }
        return mapper.credential
    }
    
    public func saveCredential(_ credential: APICredential) {
        self.updateCredential(credential)
    }
    
    public func updateCredential(_ credential: APICredential) {
        let mapper = APICredentialMapper(credential: credential)
        self.keyChainStore.update(self.key, mapper)
    }
    
    public func removeCredential() {
        self.keyChainStore.remove(self.key)
    }
}
