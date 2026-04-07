//
//  
//  EventDefaultTagSelectBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 1/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - EventDefaultTagSelectSceneBuilerImple

final class EventDefaultTagSelectSceneBuilerImple {
    
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


extension EventDefaultTagSelectSceneBuilerImple: EventDefaultTagSelectSceneBuiler {
    
    @MainActor
    func makeEventDefaultTagSelectScene() -> any EventDefaultTagSelectScene {
        
        let viewModel = EventDefaultTagSelectViewModelImple(
            tagUsecase: self.usecaseFactory.makeEventTagUsecase(),
            eventSettingUsecase: self.usecaseFactory.makeEventSettingUsecase(),
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase(),
            appleCalendarUsecase: self.usecaseFactory.makeAppleCalendarUsecase()
        )
        
        let viewController = EventDefaultTagSelectViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = EventDefaultTagSelectRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
