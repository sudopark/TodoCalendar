//
//  
//  EventTagSelectBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 1/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - EventTagSelectSceneBuilerImple

final class EventTagSelectSceneBuilerImple {
    
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


extension EventTagSelectSceneBuilerImple: EventTagSelectSceneBuiler {
    
    @MainActor
    func makeEventTagSelectScene() -> any EventTagSelectScene {
        
        let viewModel = EventTagSelectViewModelImple(
            tagUsecase: self.usecaseFactory.makeEventTagUsecase(),
            eventSettingUsecase: self.usecaseFactory.makeEventSettingUsecase(),
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase()
        )
        
        let viewController = EventTagSelectViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = EventTagSelectRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
