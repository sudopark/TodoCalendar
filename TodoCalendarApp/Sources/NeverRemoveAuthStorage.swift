//
//  NeverRemoveAuthStorage.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/6/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository


struct NeverRemoveAuthStorage: AuthStore, APICredentialStore {

    private let storage: AuthStoreImple

    init(storage: AuthStoreImple) {
        self.storage = storage
    }

    func loadCurrentAuth() -> Auth? {
        return self.storage.loadCurrentAuth()
    }

    func loadCredential() -> APICredential? {
        return self.storage.loadCredential()
    }

    func saveAuth(_ auth: Auth) {
        self.storage.saveAuth(auth)
    }

    func saveCredential(_ credential: APICredential) {
        self.storage.saveCredential(credential)
    }

    func updateCredential(_ credential: APICredential) {
        self.storage.updateCredential(credential)
    }

    func removeAuth() {
        // not remove auth
    }

    func removeCredential() {
        // not remove credential
    }
}
