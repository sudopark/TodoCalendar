//
//  ApplicationRootUsecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation
import Domain
import CommonPresentation


struct ApplicationPrepareResult {
    
    var latestLoginAcount: Account?
    let appearnceSetings: AppearanceSettings
}


// MARK: - ApplicationRootUsecase

protocol ApplicationRootUsecase {
    
    func prepareLaunch() async throws -> ApplicationPrepareResult
}


final class ApplicationRootUsecaseImple: ApplicationRootUsecase {
    
    private let accountUsecase: any AccountUsecase
    private let appSettingRepository: any AppSettingRepository
    private let sharedDataStore: SharedDataStore
    init(
        accountUsecase: any AccountUsecase,
        appSettingRepository: any AppSettingRepository,
        sharedDataStore: SharedDataStore
    ) {
        self.accountUsecase = accountUsecase
        self.appSettingRepository = appSettingRepository
        self.sharedDataStore = sharedDataStore
    }
}


extension ApplicationRootUsecaseImple {
    
    func prepareLaunch() async throws -> ApplicationPrepareResult {
        let latestLoginAccount = try await self.accountUsecase.prepareLastSignInAccount()
        let appearance = self.appSettingRepository.loadSavedViewAppearance()
        self.sharedDataStore.put(
            AppearanceSettings.self,
            key: ShareDataKeys.uiSetting.rawValue,
            appearance
        )
        return .init(
            latestLoginAcount: latestLoginAccount,
            appearnceSetings: appearance
        )
    }
}
