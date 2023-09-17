//
//  ApplicationRootViewModel.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain

final class ApplicationRootViewModelImple {
 
    private let applicationUsecase: any ApplicationRootUsecase
    var router: ApplicationRootRouter?
    
    init(applicationUsecase: any ApplicationRootUsecase) {
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
}


