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
    
    let userDefaultEnvironmentStorage = UserDefaultEnvironmentStorageImple()
    
    let keyChainStorage = KeyChainStorageImple(identifier: AppEnvironment.keyChainStoreName)
    
    lazy var commonSqliteService: SQLiteService = {
        let service = SQLiteService()
        return service
    }()
    
    private var remoteEnvironment: RemoteEnvironment = {
        // TODO: host 값 읽어와야함
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
            let authService = Auth.auth()
            if AppEnvironment.useEmulator {
                authService.useEmulator(withHost:"127.0.0.1", port:9099)
            }
            return authService
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
    func signOut() throws {
        
    }
    
    func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult {
        throw RuntimeError("failed")
    }
    
    func refreshToken(_ resultHandler: @escaping (Result<AuthRefreshResult, Error>) -> Void) {
        
    }
}
