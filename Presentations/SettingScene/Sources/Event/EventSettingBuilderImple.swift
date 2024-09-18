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
    private let eventTagSelectSceneBuilder: any EventTagSelectSceneBuiler
    private let eventDefaultNotificationTimeSceneBuilder: any EventNotificationDefaultTimeOptionSceneBuiler
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        eventTagSelectSceneBuilder: any EventTagSelectSceneBuiler,
        eventDefaultNotificationTimeSceneBuilder: any EventNotificationDefaultTimeOptionSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.eventTagSelectSceneBuilder = eventTagSelectSceneBuilder
        self.eventDefaultNotificationTimeSceneBuilder = eventDefaultNotificationTimeSceneBuilder
    }
}


extension EventSettingSceneBuilerImple: EventSettingSceneBuiler {
    
    @MainActor
    func makeEventSettingScene() -> any EventSettingScene {
        
        let viewModel = EventSettingViewModelImple(
            eventSettingUsecase: usecaseFactory.makeEventSettingUsecase(),
            eventNotificationSettingUsecase: usecaseFactory.makeEventNotificationSettingUsecase(),
            eventTagUsecase: usecaseFactory.makeEventTagUsecase()
        )
        
        let viewController = EventSettingViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = EventSettingRouter(
            eventTagSelectSceneBuilder: self.eventTagSelectSceneBuilder,
            eventDefaultNotificationTimeSceneBuilder: self.eventDefaultNotificationTimeSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
