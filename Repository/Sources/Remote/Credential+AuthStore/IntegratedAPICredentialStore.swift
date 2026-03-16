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
    
    private func key(_ serviceId: String, _ accountId: String) -> String {
        return "\(serviceId)-\(accountId)-credential"
    }

    public func loadCredential(for serviceId: String, accountId: String) -> APICredential? {
        guard let mapper: APICredentialMapper = self.keyChainStore.load(self.key(serviceId, accountId))
        else { return nil }
        return mapper.credential
    }

    public func saveCredential(for serviceId: String, accountId: String, _ credential: APICredential) {
        self.updateCredential(for: serviceId, accountId: accountId, credential)
    }

    public func updateCredential(for serviceId: String, accountId: String, _ credential: APICredential) {
        let mapper = APICredentialMapper(credential: credential)
        self.keyChainStore.update(self.key(serviceId, accountId), mapper)
    }

    public func removeCredential(for serviceId: String, accountId: String) {
        self.keyChainStore.remove(self.key(serviceId, accountId))
    }
}
