//
//  GoogleAPICredentialStore.swift
//  Repository
//
//  Created by sudo.park on 1/22/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - GoogleAPICredentialStore

public final class GoogleAPICredentialStoreImple: APICredentialStore {
    
    private let serviceIdentifier: String
    private let integratedStore: IntegratedAPICredentialStore
    public init(
        serviceIdentifier: String,
        keyChainStore: any KeyChainStorage
    ) {
        self.serviceIdentifier = serviceIdentifier
        self.integratedStore = .init(keyChainStore: keyChainStore)
    }
}

extension GoogleAPICredentialStoreImple {
    
    public func loadCredential() -> APICredential? {
        return self.integratedStore.loadCredential(for: self.serviceIdentifier)
    }
    
    public func saveCredential(_ credential: APICredential) {
        self.updateCredential(credential)
    }
    
    public func updateCredential(_ credential: APICredential) {
        self.integratedStore.updateCredential(for: self.serviceIdentifier, credential)
    }
    
    public func removeCredential() {
        self.integratedStore.removeCredential(for: self.serviceIdentifier)
    }
}
