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
    
    var latestLoginAccountId: String?
    let appearnceSetings: AppearanceSettings
}


// MARK: - ApplicationRootUsecase

protocol ApplicationRootUsecase {
    
    func prepareLaunch() async throws -> ApplicationPrepareResult
}


final class ApplicationRootUsecaseImple: ApplicationRootUsecase {
    
    private let authRepository: AuthRepository
    private let appSettingRepository: AppSettingRepository
    
    init(authRepository: AuthRepository, appSettingRepository: AppSettingRepository) {
        self.authRepository = authRepository
        self.appSettingRepository = appSettingRepository
    }
}


extension ApplicationRootUsecaseImple {
    
    func prepareLaunch() async throws -> ApplicationPrepareResult {
        let latestLoginId = try await self.authRepository.loadLatestLoginUserId()
        let appearance = self.appSettingRepository.loadSavedViewAppearance()
        return .init(
            latestLoginAccountId: latestLoginId,
            appearnceSetings: appearance
        )
    }
}