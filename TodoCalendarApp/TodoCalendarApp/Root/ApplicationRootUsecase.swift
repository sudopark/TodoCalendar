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
    
    private let authRepository: any AuthRepository
    private let uiSettingUsecase: any UISettingUsecase
    
    init(
        authRepository: any AuthRepository,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.authRepository = authRepository
        self.uiSettingUsecase = uiSettingUsecase
    }
}


extension ApplicationRootUsecaseImple {
    
    func prepareLaunch() async throws -> ApplicationPrepareResult {
        let latestLoginId = try await self.authRepository.loadLatestLoginUserId()
        let appearance = self.uiSettingUsecase.loadAppearanceSetting()
        return .init(
            latestLoginAccountId: latestLoginId,
            appearnceSetings: appearance
        )
    }
}
