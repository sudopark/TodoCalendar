//
//  ApplicationPrepareUsecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation
import Combine
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
    func prepareEnterBackground()
    func prepareSignedIn(_ auth: Auth) async
    func prepareSignedOut() async
    func prepareExternalCalendarIntegrated(_ serviceId: String)
    func prepareExternalCalendarStopIntegrated(_ serviceId: String)
}


final class ApplicationPrepareUsecaseImple: ApplicationPrepareUsecase {
    
    private let accountUsecase: any AccountUsecase
    private let supportExternalServices: [any ExternalCalendarService]
    private let externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase
    private let latestAppSettingRepository: any AppSettingRepository
    private let sharedDataStore: SharedDataStore
    private let environmentStorage: any EnvironmentStorage
    private let dbVersion: Int32
    private let database: SQLiteService
    private let databasePathFinding: (String?) -> String

    private var cancelBag: Set<AnyCancellable> = []
    
    init(
        accountUsecase: any AccountUsecase,
        supportExternalServices: [any ExternalCalendarService],
        externalCalenarIntegrationUsecase: any ExternalCalendarIntegrationUsecase,
        latestAppSettingRepository: any AppSettingRepository,
        sharedDataStore: SharedDataStore,
        environmentStorage: any EnvironmentStorage,
        dbVersion: Int32,
        database: SQLiteService,
        databasePathFinding: @escaping (String?) -> String = { AppEnvironment.dbFilePath(for: $0) }
    ) {
        self.accountUsecase = accountUsecase
        self.supportExternalServices = supportExternalServices
        self.externalCalenarIntegrationUsecase = externalCalenarIntegrationUsecase
        self.latestAppSettingRepository = latestAppSettingRepository
        self.sharedDataStore = sharedDataStore
        self.environmentStorage = environmentStorage
        self.dbVersion = dbVersion
        self.database = database
        self.databasePathFinding = databasePathFinding
    }
}


extension ApplicationPrepareUsecaseImple {
    
    func prepareLaunch() async throws -> ApplicationPrepareResult {
        let latestLoginAccount = try await self.accountUsecase.prepareLastSignInAccount()
        let appearance = try await self.prepareLatestAppearanceSeting()
        
        try? await self.prepareDatabase(for: latestLoginAccount?.auth.uid)
        
        try? await self.externalCalenarIntegrationUsecase.prepareIntegratedAccounts()
        return .init(
            latestLoginAcount: latestLoginAccount,
            appearnceSetings: appearance
        )
    }
    
    func prepareEnterBackground() {
        
        let syncResult = self.database.run { db in
            try db.execute("PRAGMA wal_checkpoint(PASSIVE);")
        }
        logger.log(.sql, level: .info, "run db sync result: \(syncResult)")
        
        self.environmentStorage.update(
            EnvironmentKeys.needCheckResetWidgetCache.rawValue,
            true
        )
        self.environmentStorage.synchronize()
    }
    
    func prepareSignedIn(_ auth: Auth) async {
        self.sharedDataStore.clearAll {
            $0 != ShareDataKeys.accountInfo.rawValue
            && $0 != ShareDataKeys.externalCalendarAccounts.rawValue
        }
        
        do {
            try await self.database.async.close()
            try? await Task.sleep(for: .milliseconds(100))
            try? await self.prepareDatabase(for: auth.uid)
        } catch let error {
            logger.log(level: .critical, "signIn -> close db failed..: \(error)")
        }
    }
    
    func prepareSignedOut() async {
        self.sharedDataStore.clearAll {
            $0 != ShareDataKeys.externalCalendarAccounts.rawValue
        }
        
        do {
            try await self.database.async.close()
            try? await Task.sleep(for: .milliseconds(100))
            try? await self.prepareDatabase(for: nil)
        } catch let error {
            logger.log(level: .critical, "signOut -> close db failed..: \(error)")
        }
    }
    
    private func prepareLatestAppearanceSeting() async throws -> AppearanceSettings  {
        let appearance = self.latestAppSettingRepository.loadSavedViewAppearance()
        self.sharedDataStore.put(
            CalendarAppearanceSettings.self,
            key: ShareDataKeys.calendarAppearance.rawValue,
            appearance.calendar
        )
        self.sharedDataStore.put(
            DefaultEventTagColorSetting.self,
            key: ShareDataKeys.defaultEventTagColor.rawValue,
            appearance.defaultTagColor
        )
        return appearance
    }
    
    private func prepareDatabase(for accountId: String?) async throws {
        let dbPath = self.databasePathFinding(accountId)
        
        do {
            try await self.database.async.open(path: dbPath)
            logger.log(.sql, level: .info, "db open -> path: \(dbPath)")
            try await self.database.runMigration(upTo: self.dbVersion)
            try await self.database.prepareTables()
        } catch {
            logger.log(.sql, level: .critical, "db open fail -> path: \(dbPath)")
            throw error
        }
    }
}


extension ApplicationPrepareUsecaseImple {
    
    func prepareExternalCalendarIntegrated(_ serviceId: String) {
        guard let service = self.supportExternalServices.first(where: { $0.identifier == serviceId })
        else { return }
        
        switch service {
        case let google as GoogleCalendarService:
            // TODO: handle connected
            break
            
        default: break
        }
    }
    
    func prepareExternalCalendarStopIntegrated(_ serviceId: String) {
        guard let service = self.supportExternalServices.first(where: { $0.identifier == serviceId })
        else { return }
        
        switch service {
        case let google as GoogleCalendarService:
            // TODO: handle disconnected
            break
            
        default: break
        }
    }
}
