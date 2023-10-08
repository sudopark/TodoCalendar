//
//  ApplicationRootBuilder.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation
import Domain
import Repository


final class ApplicationRootBuilder {
    
    func makeRootViewModel() -> ApplicationRootViewModelImple {
        
        let usecaseFactory = NonLoginUsecaseFactoryImple()
        let rootUsecase = ApplicationRootUsecaseImple(
            authRepository: FakeAuthRepository(),
            uiSettingUsecase: usecaseFactory.makeUISettingUsecase()
        )
        let rootViewModel = ApplicationRootViewModelImple(
            applicationUsecase: rootUsecase
        )
        let rootRouter = ApplicationRootRouter(nonLoginUsecaseFactory: usecaseFactory)
        rootViewModel.router = rootRouter
        
        return rootViewModel
    }
}


// MARK: - 임시로 당분간 local만 이용

final class FakeAuthRepository: AuthRepository {
    
    func loadLatestLoginUserId() async throws -> String? {
        return nil
    }
}
