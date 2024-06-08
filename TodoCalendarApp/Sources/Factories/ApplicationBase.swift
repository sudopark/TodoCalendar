//
//  ApplicationBase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain
import Repository
import Extensions
import FirebaseAuth
import Alamofire
import SQLiteService


final class ApplicationBase {
    
    init() { }
    
    let sharedDataStore: SharedDataStore = .init()
    
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
        return service
    }()
    
    private var remoteEnvironment: RemoteEnvironment = {
        
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
    
    let firebaseAuthService: any FirebaseAuthService = {
        if AppEnvironment.isTestBuild {
            return DummyFirebaseAuthService()
        } else {
            return FirebaseAuthServiceImple(
                appGroupId: AppEnvironment.groupID,
                useEmulator: AppEnvironment.useEmulator
            )
        }
    }()
    
    lazy var remoteAPI: RemoteAPIImple = {
        let environment = self.remoteEnvironment
        let authenticator = OAuthAutenticator(
            authStore: self.keyChainStorage,
            remoteEnvironment: environment,
            firebaseAuthService: self.firebaseAuthService
        )
        return RemoteAPIImple(
            environment: environment,
            authenticator: authenticator
        )
    }()
}


// MARK: - dummy

class DummyFirebaseAuthService: FirebaseAuthService {
    
    func setup() throws { }
    
    func signOut() throws {
        
    }
    
    func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult {
        throw RuntimeError("failed")
    }
    
    func refreshToken(_ resultHandler: @escaping (Result<AuthRefreshResult, Error>) -> Void) {
        
    }
}
