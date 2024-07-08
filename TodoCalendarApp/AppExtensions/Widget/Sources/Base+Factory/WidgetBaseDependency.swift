//
//  WidgetBaseDependency.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 6/8/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions
import Repository
import FirebaseCore
import FirebaseAuth
import SQLiteService
import Alamofire


// MARK: - WidgetBaseDependency

final class WidgetBaseDependency {
    
    init() { }
    
    let userDefaultEnvironmentStorage = UserDefaultEnvironmentStorageImple(
        suiteName: AppEnvironment.groupID
    )
    
    let keyChainStorage: KeyChainStorageImple = {
        let store = KeyChainStorageImple(identifier: AppEnvironment.keyChainStoreName)
        store.setupSharedGroup(AppEnvironment.groupID)
        return store
    }()
    
    lazy var commonSqliteService: SQLiteService = {
        let service = SQLiteService()
        let userId = self.keyChainStorage.loadCurrentAuth()?.uid
        let path = AppEnvironment.dbFilePath(for: userId)
        _ = service.open(path: path)
        return service
    }()
    
    private lazy var firebaseAuthService: any FirebaseAuthService = {
        if AppEnvironment.isTestBuild {
            return DummyFirebaseAuthService()
        } else {
            FirebaseApp.configure()
            return FirebaseAuthServiceImple(
                appGroupId: AppEnvironment.groupID,
                useEmulator: AppEnvironment.useEmulator
            )
        }
    }()
    
    private lazy var remoteEnvironment: RemoteEnvironment = {
        func readSecret() -> [String: Any] {
            guard let path = Bundle.main.path(forResource: "secrets", ofType: "json"),
                    let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path))
            else { return [:] }
            
            return (try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]) ?? [:]
        }
        let secrets = readSecret()
        let host = AppEnvironment.useEmulator
            ? secrets["emulator_caleandar_api_host"] as? String
            : secrets["caleandar_api_host"] as? String
        let environment = RemoteEnvironment(
            calendarAPIHost: host ?? "https://dummy.com"
        )
        return environment
    }()
    
    lazy var remoteAPI: RemoteAPIImple = {
        let environment = self.remoteEnvironment
        let authStore = NeverRemoveAuthStorage(storage: self.keyChainStorage)
        let authenticator = OAuthAutenticator(
            authStore: authStore,
            remoteEnvironment: environment,
            firebaseAuthService: self.firebaseAuthService
        )
        return RemoteAPIImple(
            environment: environment,
            authenticator: authenticator
        )
    }()
}


// MARK: - NeverRemoveAuthStorage

struct NeverRemoveAuthStorage: AuthStore  {
    
    private let storage: KeyChainStorageImple
    init(storage: KeyChainStorageImple) {
        self.storage = storage
    }
    
    func loadCurrentAuth() -> Domain.Auth? {
        return self.storage.loadCurrentAuth()
    }
    
    func updateAuth(_ auth: Domain.Auth) {
        self.storage.updateAuth(auth)
    }
    
    func removeAuth() {
        // not remove auth
    }
}

// MARK: - dummy

class DummyFirebaseAuthService: FirebaseAuthService {
    
    func setup() throws {
        
    }
    
    func signOut() throws {
        
    }
    
    func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult {
        throw RuntimeError("failed")
    }
    
    func refreshToken(_ resultHandler: @escaping (Result<AuthRefreshResult, Error>) -> Void) {
        
    }
}
