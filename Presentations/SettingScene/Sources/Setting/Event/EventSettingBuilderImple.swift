//
//  
//  EventSettingBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - EventSettingSceneBuilerImple

final class EventSettingSceneBuilerImple {
    
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


extension EventSettingSceneBuilerImple: EventSettingSceneBuiler {
    
    @MainActor
    func makeEventSettingScene() -> any EventSettingScene {
        
        let viewModel = EventSettingViewModelImple(
            eventSettingUsecase: usecaseFactory.makeEventSettingUsecase(),
            eventTagUsecase: usecaseFactory.makeEventTagUsecase()
        )
        
        let viewController = EventSettingViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = EventSettingRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
