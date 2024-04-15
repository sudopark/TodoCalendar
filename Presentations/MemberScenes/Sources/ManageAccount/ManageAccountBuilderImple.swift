//
//  
//  ManageAccountBuilderImple.swift
//  MemberScenes
//
//  Created by sudo.park on 4/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - ManageAccountSceneBuilerImple

final class ManageAccountSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension ManageAccountSceneBuilerImple: ManageAccountSceneBuiler {
    
    @MainActor
    func makeManageAccountScene() -> any ManageAccountScene {
        
        let viewModel = ManageAccountViewModelImple(
            authUsecase: self.usecaseFactory.authUsecase,
            accountUsecase: self.usecaseFactory.accountUescase,
            migrationUsecase: self.usecaseFactory.temporaryUserDataMigrationUsecase
        )
        
        let viewController = ManageAccountViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = ManageAccountRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
