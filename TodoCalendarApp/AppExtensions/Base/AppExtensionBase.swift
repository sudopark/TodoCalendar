

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
        suiteName: AppEnvironment.userDefaultSuiteName
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
    
    lazy var externalCalendarDBConnectionPool: AppExtensionExternalCalendarDBConnectionPool = {
        let dbPaths = AppEnvironment.externalCalendarDBPaths()
        var services: [String: SQLiteService] = [:]
        for (serviceId, path) in dbPaths {
            let service = SQLiteService(openWithReadOnly: true)
            _ = service.open(path: path)
            services[serviceId] = service
        }
        return AppExtensionExternalCalendarDBConnectionPool(services: services)
    }()

    lazy var appleCalendarPermissionChecker: AppleCalendarPermissionCheckerImple = {
        return AppleCalendarPermissionCheckerImple(storeAccessor: EKEventStoreWrapper())
    }()
    
    lazy var firebaseAuthService: any FirebaseAuthService = {
        if AppEnvironment.isExternalDependencyBlocked {
            return DummyFirebaseAuthService()
        } else {
            // 앱 프로세스에서는 AppDelegate가 먼저 configure 한다 — 두 번 부르면 예외가 난다.
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
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
        let host = AppEnvironment.calendarAPIHost(secrets: secrets)
        let csAPi = secrets["cs_api"] as? String
        let environment = RemoteEnvironment(
            calendarAPIHost: host ?? "https://dummy.com",
            csAPI: csAPi ?? "https://dummy.com",
            deviceId: AppEnvironment.deviceId(self.userDefaultEnvironmentStorage),
            acceptLanguage: { AcceptLanguage.headerValue(from: Locale.preferredLanguages) }
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


actor AppExtensionExternalCalendarDBConnectionPool: ExternalCalendarDBConnectionPool {

    private let services: [String: SQLiteService]
    init(services: [String: SQLiteService]) {
        self.services = services
    }

    func hasConnection(serviceId: String) -> Bool {
        return self.services[serviceId] != nil
    }

    func connection(serviceId: String) async throws -> SQLiteService {
        guard let service = self.services[serviceId] else {
            throw RuntimeError("no db connection for service: \(serviceId)")
        }
        return service
    }
}
