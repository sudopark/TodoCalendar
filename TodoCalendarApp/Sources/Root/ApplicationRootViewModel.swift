//
//  ApplicationRootViewModel.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain

final class ApplicationRootViewModelImple: @unchecked Sendable {
 
    private let authUsecase: any AuthUsecase
    private let applicationUsecase: any ApplicationRootUsecase
    var router: ApplicationRootRouter?
    
    init(
        authUsecase: any AuthUsecase,
        applicationUsecase: any ApplicationRootUsecase
    ) {
        self.authUsecase = authUsecase
        self.applicationUsecase = applicationUsecase
    }
}


extension ApplicationRootViewModelImple {
    
    func prepareInitialScene() {
        Task {
            let result = try await self.applicationUsecase.prepareLaunch()
            self.router?.setupInitialScene(result)
        }
    }
    
    func handle(open url: URL) -> Bool {
        if self.authUsecase.handleAuthenticationResultOrNot(open: url) {
            return true
        }
        return false
    }
}


