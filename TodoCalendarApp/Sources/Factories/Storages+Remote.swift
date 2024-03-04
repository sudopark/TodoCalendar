//
//  Singleton.swift
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


final class Singleton {
    
    private init() { }
    
    static let shared = Singleton()
    
    let sharedDataStore: SharedDataStore = .init()
    
    let userDefaultEnvironmentStorage = UserDefaultEnvironmentStorageImple()
    
    let keyChainStorage = KeyChainStorageImple(identifier: AppEnvironment.keyChainStoreName)
    
    lazy var commonSqliteService: SQLiteService = {
        let service = SQLiteService()
        return service
    }()
    
    // TODO: test build 이면 empty remote 객체 제공
    private var remoteEnvironment: RemoteEnvironment = {
        // TODO: host 값 읽어와야함
        let environment = RemoteEnvironment(calendarAPIHost: "some")
        return environment
    }()
    
    let firebaseAuthService: any FirebaseAuthService = {
        if AppEnvironment.isTestBuild {
            return DummyFirebaseAuthService()
        } else {
            return Auth.auth()
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
    
    func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult {
        throw RuntimeError("failed")
    }
    
    func refreshToken(_ resultHandler: @escaping (Result<AuthRefreshResult, Error>) -> Void) {
        
    }
}
