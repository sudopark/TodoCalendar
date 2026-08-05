//
//  AICommandIntentFactory.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/6/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository
import SQLiteService
import Alamofire


// 앱 라이프사이클(prepareInitialScene → UsecaseFactory)에 의존하지 않는 인텐트 전용 조립.
// openAppWhenRun = false 는 scene 없이 기동돼 그 경로가 돌지 않는다.
struct AICommandIntentFactory {

    private let environmentStorage: UserDefaultEnvironmentStorageImple
    private let authStore: AuthStoreImple
    private let firebaseAuthService: any FirebaseAuthService

    init() {
        let environmentStorage = UserDefaultEnvironmentStorageImple(
            suiteName: AppEnvironment.groupID
        )
        let keyChainStorage = KeyChainStorageImple(
            identifier: AppEnvironment.keyChainStoreName
        )
        keyChainStorage.setupSharedGroup(AppEnvironment.groupID)

        // 앱에서 이 setup 은 prepareLaunch 경로가 부른다 — 백그라운드 기동엔 안 도니 직접 부른다
        let firebaseAuthService = FirebaseAuthServiceImple(
            appGroupId: AppEnvironment.groupID,
            useEmulator: AppEnvironment.useEmulator
        )
        try? firebaseAuthService.setup()

        self.environmentStorage = environmentStorage
        self.authStore = AuthStoreImple(
            keyChainStorage: keyChainStorage,
            environmentStorage: environmentStorage
        )
        self.firebaseAuthService = firebaseAuthService
    }
}

extension AICommandIntentFactory {

    func makeSubmitService() -> IntentCommandSubmitService {
        return IntentCommandSubmitService(
            repository: self.makeAICommandRepository(),
            authStore: self.authStore,
            settingRepository: CalendarSettingRepositoryImple(
                environmentStorage: self.environmentStorage
            )
        )
    }

    // job 생성 + 처리중 기록 두 가지만 필요하므로 usecase가 아닌 repository를 직접 만든다.
    private func makeAICommandRepository() -> any AICommandRepository {
        let auth = self.authStore.loadCurrentAuth()
        let remoteAPI = self.makeRemoteAPI()
        // AI 엔드포인트는 인증 필수(CalendarAPIAutenticator.shouldAdapt).
        // auth를 seed하지 않으면 무인증으로 나간다 — ShareUsecaseFactory와 같은 처리.
        if let auth {
            remoteAPI.setup(credential: APICredential(auth: auth))
        }

        let sqliteService = SQLiteService(openWithReadOnly: false)
        _ = sqliteService.open(path: AppEnvironment.dbFilePath(for: auth?.uid))
        return AICommandRepositoryImple(
            remote: remoteAPI,
            localStorage: AICommandLocalStorageImple(sqliteService: sqliteService)
        )
    }

    private func makeRemoteAPI() -> RemoteAPIImple {

        func readSecret() -> [String: Any] {
            guard let path = Bundle.main.path(forResource: "secrets", ofType: "json"),
                  let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path))
            else { return [:] }
            return (try? JSONSerialization.jsonObject(
                with: jsonData, options: .allowFragments
            ) as? [String: Any]) ?? [:]
        }
        let secrets = readSecret()
        let host = AppEnvironment.useEmulator
            ? secrets["emulator_caleandar_api_host"] as? String
            : secrets["caleandar_api_host"] as? String
        let environment = RemoteEnvironment(
            calendarAPIHost: host ?? "https://dummy.com",
            csAPI: secrets["cs_api"] as? String ?? "https://dummy.com",
            deviceId: AppEnvironment.deviceId(self.environmentStorage),
            acceptLanguage: { AcceptLanguage.headerValue(from: Locale.preferredLanguages) }
        )
        let configure = URLSessionConfiguration.af.default
        configure.timeoutIntervalForRequest = AppEnvironment.apiDefaultTimeoutSeconds
        let session = Session(
            configuration: configure,
            serializationQueue: DispatchQueue(label: "af.serialization", qos: .utility)
        )
        let authenticator = CalendarAPIAutenticator(
            credentialStore: NeverRemoveAuthStorage(storage: self.authStore),
            firebaseAuthService: self.firebaseAuthService
        )
        return RemoteAPIImple(
            session: session,
            environment: environment,
            interceptor: AuthenticationInterceptorProxy(authenticator: authenticator)
        )
    }
}
