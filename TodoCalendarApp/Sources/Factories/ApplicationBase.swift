//
//  ApplicationBase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import UIKit
import Prelude
import Optics
import Domain
import Repository
import Extensions
import FirebaseAuth
import Alamofire
import SQLiteService
import SwiftLinkPreview


final class ApplicationBase {
    
    init() { }
    
    let sharedDataStore: SharedDataStore = .init()
    let eventNotifyService: SharedEventNotifyService = .init()
    
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
    
    let linkPreviewEngine: SwiftLinkPreview = {
       return SwiftLinkPreview(cache: InMemoryCache())
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
        let csAPi = secrets["cs_api"] as? String
        let environment = RemoteEnvironment(
            calendarAPIHost: host ?? "https://dummy.com",
            csAPI: csAPi ?? "https://dummy.com",
            deviceId: AppEnvironment.deviceId(userDefaultEnvironmentStorage)
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
    
    lazy var googleCalendarRemoteAPI: RemoteAPIImple = {
        
        func readClientId() -> String {
            let plist = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
                .map { URL(fileURLWithPath: $0) }
                .flatMap { try? Data(contentsOf: $0) }
                .flatMap {
                    try? PropertyListSerialization.propertyList(from: $0, format: nil)
                }
                .flatMap { $0 as? [String: Any] }
            return plist?["CLIENT_ID"] as? String ?? "dummy_id"
        }
        let environment = self.remoteEnvironment
        let googleAPICredentialStore = GoogleAPICredentialStoreImple(
            serviceIdentifier: AppEnvironment.googleCalendarService.identifier,
            keyChainStore: self.keyChainStorage
        )
        let authenticator = GoogleAPIAuthenticator(
            googleClientId: readClientId(),
            credentialStore: googleAPICredentialStore
        )
        let interceptor = AuthenticationInterceptorProxy(authenticator: authenticator)
        let remote = RemoteAPIImple(
            session: self.remoteSession,
            environment: environment,
            interceptor: interceptor
        )
        authenticator.remoteAPI = remote
        return remote
    }()
}


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
