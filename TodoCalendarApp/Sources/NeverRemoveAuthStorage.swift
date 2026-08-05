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


// 유저 없는 백그라운드에서 리프레시가 일시 실패했다고 세션을 지우면 조용히 로그아웃된다.
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
