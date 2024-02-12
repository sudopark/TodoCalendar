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
    
    var latestLoginAuth: Auth?
    let appearnceSetings: AppearanceSettings
}


// MARK: - ApplicationRootUsecase

protocol ApplicationRootUsecase {
    
    func prepareLaunch() async throws -> ApplicationPrepareResult
}


final class ApplicationRootUsecaseImple: ApplicationRootUsecase {
    
    private let authRepository: any AuthRepository
    private let appSettingRepository: any AppSettingRepository
    private let sharedDataStore: SharedDataStore
    init(
        authRepository: any AuthRepository,
        appSettingRepository: any AppSettingRepository,
        sharedDataStore: SharedDataStore
    ) {
        self.authRepository = authRepository
        self.appSettingRepository = appSettingRepository
        self.sharedDataStore = sharedDataStore
    }
}


extension ApplicationRootUsecaseImple {
    
    func prepareLaunch() async throws -> ApplicationPrepareResult {
        let latestLoginAuth = try await self.authRepository.loadLatestSignInAuth()
        let appearance = self.appSettingRepository.loadSavedViewAppearance()
        self.sharedDataStore.put(
            AppearanceSettings.self,
            key: ShareDataKeys.uiSetting.rawValue,
            appearance
        )
        return .init(
            latestLoginAuth: latestLoginAuth,
            appearnceSetings: appearance
        )
    }
}
