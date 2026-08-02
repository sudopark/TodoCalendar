//
//  ApplicationBase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit
import EventKit
import Prelude
import Optics
import Domain
import Repository
import Extensions
import FirebaseAuth
import Alamofire
import SQLiteService
import ExternalServices
import StoreKitService


final class ApplicationBase {

    init() {
        // remoteAPI·sharedDataStore 준비가 끝난 뒤 리스너를 앱 수명으로 1회 기동한다.
        // billingUsecase 가 다른 lazy 프로퍼티(remoteAPI 등)를 참조하므로 이 시점엔 lazy var여야
        // self 를 phase-1 초기화 제약 없이 쓸 수 있다 (let 로는 컴파일 불가)
        self.billingUsecase.startObservingTransactions()
    }

    let sharedDataStore: SharedDataStore = .init()
    let eventNotifyService: SharedEventNotifyService = .init()

    // 트랜잭션 리스너는 앱 수명 단일 인스턴스여야 한다 — 로그인 세션에 묶으면 로그아웃 구간에
    // 리스너가 사라지고, 팩토리 교체 순간 둘이 공존해 같은 JWS 를 중복 POST 한다 (#739)
    lazy var billingUsecase: any BillingUsecase = {
        return BillingUsecaseImple(
            repository: BillingRepositoryImple(remote: self.remoteAPI),
            appStoreService: AppStoreBillingServiceImple(),
            sharedDataStore: self.sharedDataStore
        )
    }()
    
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
        let service = SQLiteService()
        return service
    }()
    
    lazy var externalCalendarDBConnectionPool: ExternalCalendarSQLiteConnectionPoolImple = {
        return ExternalCalendarSQLiteConnectionPoolImple(
            dbPathMap: AppEnvironment.externalCalendarDBPaths(),
            onFirstOpen: { service in
                let googleDBVersion = AppEnvironment.googleCalendarDBVersion
                let _ = try await service.async.migrate(
                    upto: googleDBVersion,
                    steps: { version, database in
                        switch version {
                        default: break
                        }
                    },
                    finalized: { version, database in
                        logger.log(.sql, level: .info, "external calendar db migration finished to: \(version)")
                        try? database.updateJournalMode("WAL")
                    }
                )
            }
        )
    }()
    
    let linkPreviewFetchEngine: any LinkPreviewFetchEngine = SwiftLinkPreviewBaseFetchEngineImple()
    
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
        let csAPi = secrets["cs_api"] as? String
        let environment = RemoteEnvironment(
            calendarAPIHost: host ?? "https://dummy.com",
            csAPI: csAPi ?? "https://dummy.com",
            deviceId: AppEnvironment.deviceId(userDefaultEnvironmentStorage),
            acceptLanguage: { AcceptLanguage.headerValue(from: Locale.preferredLanguages) }
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
        let authenticator = CalendarAPIAutenticator(
            credentialStore: self.authStore,
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
    
    private func readGoogleClientId() -> String {
        let plist = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
            .map { URL(fileURLWithPath: $0) }
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) }
            .flatMap { $0 as? [String: Any] }
        return plist?["CLIENT_ID"] as? String ?? "dummy_id"
    }

    lazy var externalCalendarAccountRemotePool: ExternalCalendarAccountRemotePoolImple = {
        let factory = ApplicationGoogleRemoteFactory(
            googleClientId: self.readGoogleClientId(),
            session: self.remoteSession,
            environment: self.remoteEnvironment,
            keyChainStore: self.keyChainStorage
        )
        return ExternalCalendarAccountRemotePoolImple(factory: factory)
    }()

    lazy var googleCalendarRepositoryPool: GoogleCalendarRepositoryPoolImple = {
        return GoogleCalendarRepositoryPoolImple(
            accountRemotePool: self.externalCalendarAccountRemotePool,
            connectionPool: self.externalCalendarDBConnectionPool
        )
    }()

    private lazy var ekEventStoreWrapper: EKEventStoreWrapper = {
        return EKEventStoreWrapper()
    }()

    lazy var appleCalendarPermissionChecker: AppleCalendarPermissionCheckerImple = {
        return AppleCalendarPermissionCheckerImple(storeAccessor: self.ekEventStoreWrapper)
    }()

    lazy var appleCalendarRepository: AppleCalendarRepositoryImple = {
        let cacheStorage = AppleCalendarLocalStorageImple(
            connectionPool: self.externalCalendarDBConnectionPool
        )
        return AppleCalendarRepositoryImple(
            storeAccessor: self.ekEventStoreWrapper,
            cacheStorage: cacheStorage
        )
    }()
}


// MARK: - ApplicationGoogleRemoteFactory

private final class ApplicationGoogleRemoteFactory: ExternalCalendarRemoteFactory, @unchecked Sendable {

    private let googleClientId: String
    private let session: Session
    private let environment: RemoteEnvironment
    private let keyChainStore: any KeyChainStorage

    init(
        googleClientId: String,
        session: Session,
        environment: RemoteEnvironment,
        keyChainStore: any KeyChainStorage
    ) {
        self.googleClientId = googleClientId
        self.session = session
        self.environment = environment
        self.keyChainStore = keyChainStore
    }

    func make(serviceId: String, accountId: String) -> (any RemoteAPI)? {
        guard serviceId == GoogleCalendarService.id else { return nil }
        let credentialStore = GoogleAPICredentialStoreImple(
            serviceIdentifier: serviceId,
            accountId: accountId,
            keyChainStore: keyChainStore
        )
        let authenticator = GoogleAPIAuthenticator(
            googleClientId: googleClientId,
            credentialStore: credentialStore
        )
        let interceptor = AuthenticationInterceptorProxy(authenticator: authenticator)
        let remote = RemoteAPIImple(
            session: session,
            environment: environment,
            interceptor: interceptor
        )
        authenticator.remoteAPI = remote
        return remote
    }
}


// MARK: -

struct DeviceInfoFetchServiceImple: DeviceInfoFetchService {
    
    @MainActor
    func fetchDeviceInfo() async -> DeviceInfo {
        return DeviceInfo()
        |> \.appVersion .~ appVersion()
        |> \.osVersion .~ pure(osVersion())
        |> \.deviceModel .~ deviceModel()
        |> \.isiOSAppOnMac .~ pure(isiOSAppOnMac)
    }
    
    private func markettingVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    private func buildNumber() -> String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }
    
    private func appVersion() -> String? {
        let markettingVersion = self.markettingVersion()
        let buildNumber = self.buildNumber()
        return markettingVersion.map {
            return "\($0)(\(buildNumber ?? "0"))"
        }
    }

    func fetchAppVersion() -> String? {
        return self.markettingVersion()
    }
    
    @MainActor
    private func osVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    private func deviceModel() -> String? {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        return modelCode
    }
    
    private var isiOSAppOnMac: Bool {
        return ProcessInfo.processInfo.isiOSAppOnMac
    }
}

// MARK: - dummy

class DummyFirebaseAuthService: FirebaseAuthService {
    
    func setup() throws { }
    
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
