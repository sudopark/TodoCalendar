//
//  ApplicationPrepareLaunchUsecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation
import Domain
import CommonPresentation
import Extensions
import Repository
import SQLiteService

struct ApplicationPrepareResult {
    
    var latestLoginAcount: Account?
    let appearnceSetings: AppearanceSettings
}


// MARK: - ApplicationRootUsecase

protocol ApplicationPrepareLaunchUsecase {
    
    func prepareLaunch() async throws -> ApplicationPrepareResult
}


final class ApplicationPrepareLaunchUsecaseImple: ApplicationPrepareLaunchUsecase {
    
    private let accountUsecase: any AccountUsecase
    private let latestAppSettingRepository: any AppSettingRepository
    private let sharedDataStore: SharedDataStore
    private let remoteAPI: any RemoteAPI
    private let database: SQLiteService
    private let databasePathFinding: (String?) -> String
    init(
        accountUsecase: any AccountUsecase,
        latestAppSettingRepository: any AppSettingRepository,
        sharedDataStore: SharedDataStore,
        remoteAPI: any RemoteAPI,
        database: SQLiteService,
        databasePathFinding: @escaping (String?) -> String = { AppEnvironment.dbFilePath(for: $0) }
    ) {
        self.accountUsecase = accountUsecase
        self.latestAppSettingRepository = latestAppSettingRepository
        self.sharedDataStore = sharedDataStore
        self.remoteAPI = remoteAPI
        self.database = database
        self.databasePathFinding = databasePathFinding
    }
}


extension ApplicationPrepareLaunchUsecaseImple {
    
    func prepareLaunch() async throws -> ApplicationPrepareResult {
        let latestLoginAccount = try await self.accountUsecase.prepareLastSignInAccount()
        let appearance = try await self.prepareLatestAppearanceSeting()
        
        self.prepareRemoteAuthenticateCredentialIfNeed(latestLoginAccount?.auth)
        self.prepareDatabase(for: latestLoginAccount?.auth.uid)
        
        return .init(
            latestLoginAcount: latestLoginAccount,
            appearnceSetings: appearance
        )
    }
    
    private func prepareLatestAppearanceSeting() async throws -> AppearanceSettings  {
        let appearance = self.latestAppSettingRepository.loadSavedViewAppearance()
        self.sharedDataStore.put(
            AppearanceSettings.self,
            key: ShareDataKeys.uiSetting.rawValue,
            appearance
        )
        return appearance
    }
    
    private func prepareRemoteAuthenticateCredentialIfNeed(_ auth: Auth?) {
        self.remoteAPI.setup(credential: auth)
    }
    
    // TODO: 추후 db switching은 별도 객체 만들것임
    private func prepareDatabase(for accountId: String?) {
        let database = self.database
        let dbPath = self.databasePathFinding(accountId)
        let openResult = database.open(path: dbPath)
        logger.log(level: .info, "db open result: \(openResult) -> path: \(dbPath)")
    }
}
