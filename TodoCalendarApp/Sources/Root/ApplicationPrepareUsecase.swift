//
//  ApplicationPrepareUsecase.swift
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

protocol ApplicationPrepareUsecase {
    
    func prepareLaunch() async throws -> ApplicationPrepareResult
    func prepareSignedIn(_ auth: Auth)
    func prepareSignedOut()
}


final class ApplicationUsecaseImple: ApplicationPrepareUsecase {
    
    private let accountUsecase: any AccountUsecase
    private let latestAppSettingRepository: any AppSettingRepository
    private let sharedDataStore: SharedDataStore
    private let database: SQLiteService
    private let databasePathFinding: (String?) -> String
    init(
        accountUsecase: any AccountUsecase,
        latestAppSettingRepository: any AppSettingRepository,
        sharedDataStore: SharedDataStore,
        database: SQLiteService,
        databasePathFinding: @escaping (String?) -> String = { AppEnvironment.dbFilePath(for: $0) }
    ) {
        self.accountUsecase = accountUsecase
        self.latestAppSettingRepository = latestAppSettingRepository
        self.sharedDataStore = sharedDataStore
        self.database = database
        self.databasePathFinding = databasePathFinding
    }
}


extension ApplicationUsecaseImple {
    
    func prepareLaunch() async throws -> ApplicationPrepareResult {
        let latestLoginAccount = try await self.accountUsecase.prepareLastSignInAccount()
        let appearance = try await self.prepareLatestAppearanceSeting()
        
        self.prepareDatabase(for: latestLoginAccount?.auth.uid)
        
        return .init(
            latestLoginAcount: latestLoginAccount,
            appearnceSetings: appearance
        )
    }
    
    func prepareSignedIn(_ auth: Auth) {
        // TODO: close and open database
    }
    
    func prepareSignedOut() {
        // TODO: close and open database
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
    
    // TODO: 추후 db switching은 별도 객체 만들것임
    private func prepareDatabase(for accountId: String?) {
        let database = self.database
        let dbPath = self.databasePathFinding(accountId)
        let openResult = database.open(path: dbPath)
        logger.log(level: .info, "db open result: \(openResult) -> path: \(dbPath)")
    }
}
