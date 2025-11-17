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
import Domain
import Scenes
import CommonPresentation


// MARK: - EventSettingSceneBuilerImple

final class EventSettingSceneBuilerImple {
    
    private let supportExternalCalendarServices: [any ExternalCalendarService]
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let eventTagSelectSceneBuilder: any EventTagSelectSceneBuiler
    private let eventDefaultNotificationTimeSceneBuilder: any EventNotificationDefaultTimeOptionSceneBuiler
    private let eventDefaultMapAppSceneBuilder: any EventDefaultMapAppSceneBuiler
    
    init(
        supportExternalCalendarServices: [any ExternalCalendarService],
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        eventTagSelectSceneBuilder: any EventTagSelectSceneBuiler,
        eventDefaultNotificationTimeSceneBuilder: any EventNotificationDefaultTimeOptionSceneBuiler,
        eventDefaultMapAppSceneBuilder: any EventDefaultMapAppSceneBuiler
    ) {
        self.supportExternalCalendarServices = supportExternalCalendarServices
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.eventTagSelectSceneBuilder = eventTagSelectSceneBuilder
        self.eventDefaultNotificationTimeSceneBuilder = eventDefaultNotificationTimeSceneBuilder
        self.eventDefaultMapAppSceneBuilder = eventDefaultMapAppSceneBuilder
    }
}


extension EventSettingSceneBuilerImple: EventSettingSceneBuiler {
    
    @MainActor
    func makeEventSettingScene() -> any EventSettingScene {
        
        let viewModel = EventSettingViewModelImple(
            eventSettingUsecase: usecaseFactory.makeEventSettingUsecase(),
            eventNotificationSettingUsecase: usecaseFactory.makeEventNotificationSettingUsecase(),
            eventTagUsecase: usecaseFactory.makeEventTagUsecase(),
            supportExternalCalendarServices: supportExternalCalendarServices,
            externalCalendarServiceUsecase: usecaseFactory.externalCalenarIntegrationUsecase
        )
        
        let viewController = EventSettingViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = EventSettingRouter(
            eventTagSelectSceneBuilder: self.eventTagSelectSceneBuilder,
            eventDefaultNotificationTimeSceneBuilder: self.eventDefaultNotificationTimeSceneBuilder,
            eventDefaultMapAppSceneBuilder: self.eventDefaultMapAppSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
