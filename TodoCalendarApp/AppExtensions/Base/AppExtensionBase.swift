

import Foundation
import Domain
import Extensions
import Repository
import FirebaseCore
import FirebaseAuth
import SQLiteService
import Alamofire


// MARK: - AppExtensionBase

final class AppExtensionBase {
    
    init() { }
    
    let userDefaultEnvironmentStorage = UserDefaultEnvironmentStorageImple(
        suiteName: AppEnvironment.groupID
    )
    
    let keyChainStorage: KeyChainStorageImple = {
        let store = KeyChainStorageImple(identifier: AppEnvironment.keyChainStoreName)
        store.setupSharedGroup(AppEnvironment.groupID)
        return store
    }()
    
    lazy var authStore: AuthStoreImple = {
        return AuthStoreImple(
            keyChainStorage: self.keyChainStorage,
            environmentStorage: self.userDefaultEnvironmentStorage
        )
    }()
    
    lazy var commonSqliteService: SQLiteService = {
        let service = SQLiteService(openWithReadOnly: true)
        let userId = self.authStore.loadCurrentAuth()?.uid
        let path = AppEnvironment.dbFilePath(for: userId)
        _ = service.open(path: path)
        return service
    }()
    
    lazy var writableSqliteService: SQLiteService = {
        let service = SQLiteService(openWithReadOnly: false)
        let userId = self.authStore.loadCurrentAuth()?.uid
        let path = AppEnvironment.dbFilePath(for: userId)
        _ = service.open(path: path)
        return service
    }()
    
    lazy var firebaseAuthService: any FirebaseAuthService = {
        if AppEnvironment.isTestBuild {
            return DummyFirebaseAuthService()
        } else {
            FirebaseApp.configure()
            let service = FirebaseAuthServiceImple(
                appGroupId: AppEnvironment.groupID,
                useEmulator: AppEnvironment.useEmulator
            )
            try? service.setup()
            return service
        }
    }()
    
    lazy var remoteEnvironment: RemoteEnvironment = {
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
        let csAPi = secrets["cs_api"] as? String
        let environment = RemoteEnvironment(
            calendarAPIHost: host ?? "https://dummy.com",
            csAPI: csAPi ?? "https://dummy.com",
            deviceId: AppEnvironment.deviceId(self.userDefaultEnvironmentStorage)
        )
        return environment
    }()
    
    var remoteSession: Session = {
        let configure = URLSessionConfiguration.af.default
        configure.timeoutIntervalForRequest = AppEnvironment.apiDefaultTimeoutSeconds
        return Session(
            configuration: configure,
            serializationQueue: DispatchQueue(label: "af.serialization", qos: .utility)
        )
    }()
    
    lazy var remoteAPI: RemoteAPIImple = {
        let environment = self.remoteEnvironment
        let authStore = NeverRemoveAuthStorage(storage: self.authStore)
        let authenticator = CalendarAPIAutenticator(
            credentialStore: authStore,
            firebaseAuthService: self.firebaseAuthService
        )
        let interceptor = AuthenticationInterceptorProxy(
            authenticator: authenticator
        )
        return RemoteAPIImple(
            session: self.remoteSession,
            environment: environment,
            interceptor: interceptor
        )
    }()
}

// MARK: - NeverRemoveAuthStorage

struct NeverRemoveAuthStorage: AuthStore, APICredentialStore  {
    
    private let storage: AuthStoreImple
    init(storage: AuthStoreImple) {
        self.storage = storage
    }
    
    func loadCurrentAuth() -> Domain.Auth? {
        return self.storage.loadCurrentAuth()
    }
    
    func loadCredential() -> APICredential? {
        return self.loadCurrentAuth().map { .init(auth: $0) }
    }
    
    func saveCredential(_ credential: APICredential) {
        self.updateCredential(credential)
    }
    
    func saveAuth(_ auth: Domain.Auth) {
        self.storage.saveAuth(auth)
    }
    
    func removeAuth() {
        // not remove auth
    }
    
    func updateCredential(_ credential: APICredential) {
        self.storage.updateCredential(credential)
    }
    
    func removeCredential() {
        // not remove credential
    }
}

// MARK: - dummy

class DummyFirebaseAuthService: FirebaseAuthService {
    
    func setup() throws {
        
    }
    
    func signOut() throws {
        
    }
    
    func deleteAccount() async throws {
        
    }
    
    func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult {
        throw RuntimeError("failed")
    }
    
    func refreshToken(_ resultHandler: @escaping (Result<AuthRefreshResult, Error>) -> Void) {
        
    }
}

final class EmptyRemote: RemoteAPI {
 
    func request(_ method: RemoteAPIMethod, _ endpoint: any Endpoint, with header: [String : String]?, parameters: [String : Any]) async throws -> Data {
        throw RuntimeError("not support")
    }
    
    func attach(listener: any AutenticatorTokenRefreshListener) { }
    
    func setup(credential: APICredential?) { }
}
