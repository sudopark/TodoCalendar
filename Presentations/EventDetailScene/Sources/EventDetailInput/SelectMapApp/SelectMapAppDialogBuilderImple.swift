//
//  
//  SelectMapAppDialogBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - SelectMapAppDialogSceneBuilerImple

final class SelectMapAppDialogSceneBuilerImple {
    
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


extension SelectMapAppDialogSceneBuilerImple: SelectMapAppDialogSceneBuiler {
    
    @MainActor
    func makeSelectMapAppDialogScene(
        query: String,
        supportMapApps: [SupportMapApps]
    ) -> any SelectMapAppDialogScene {
        
        let viewModel = SelectMapAppDialogViewModelImple(
            query: query, supportMapApps: supportMapApps,
            eventSettingUsecase: usecaseFactory.makeEventSettingUsecase()
        )
        
        let viewController = SelectMapAppDialogViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = SelectMapAppDialogRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
