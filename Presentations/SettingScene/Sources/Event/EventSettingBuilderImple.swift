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
import CommonPresentation
import ExternalCalendarDomainInterface
import SceneInfra


// MARK: - EventSettingSceneBuilerImple

final class EventSettingSceneBuilerImple {
    
    private let supportExternalCalendarServices: [any ExternalCalendarService]
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let eventTagSelectSceneBuilder: any EventDefaultTagSelectSceneBuiler
    private let eventDefaultNotificationTimeSceneBuilder: any EventNotificationDefaultTimeOptionSceneBuiler
    private let eventDefaultMapAppSceneBuilder: any EventDefaultMapAppSceneBuiler
    private let selectGoogleCalendarDialogSceneBuilder: any SelectGoogleCalendarDialogSceneBuiler
    
    init(
        supportExternalCalendarServices: [any ExternalCalendarService],
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        eventTagSelectSceneBuilder: any EventDefaultTagSelectSceneBuiler,
        eventDefaultNotificationTimeSceneBuilder: any EventNotificationDefaultTimeOptionSceneBuiler,
        eventDefaultMapAppSceneBuilder: any EventDefaultMapAppSceneBuiler,
        selectGoogleCalendarDialogSceneBuilder: any SelectGoogleCalendarDialogSceneBuiler
    ) {
        self.supportExternalCalendarServices = supportExternalCalendarServices
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.eventTagSelectSceneBuilder = eventTagSelectSceneBuilder
        self.eventDefaultNotificationTimeSceneBuilder = eventDefaultNotificationTimeSceneBuilder
        self.eventDefaultMapAppSceneBuilder = eventDefaultMapAppSceneBuilder
        self.selectGoogleCalendarDialogSceneBuilder = selectGoogleCalendarDialogSceneBuilder
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
            externalCalendarServiceUsecase: usecaseFactory.externalCalenarIntegrationUsecase,
            accountUsecase: usecaseFactory.accountUescase,
            eventSyncUsecase: usecaseFactory.eventSyncUsecase,
            calendarSettingUsecase: usecaseFactory.makeCalendarSettingUsecase(),
            googleCalendarUsecase: usecaseFactory.makeGoogleCalendarUsecase()
        )
        
        let viewController = EventSettingViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = EventSettingRouter(
            eventTagSelectSceneBuilder: self.eventTagSelectSceneBuilder,
            eventDefaultNotificationTimeSceneBuilder: self.eventDefaultNotificationTimeSceneBuilder,
            eventDefaultMapAppSceneBuilder: self.eventDefaultMapAppSceneBuilder,
            selectGoogleCalendarDialogSceneBuilder: self.selectGoogleCalendarDialogSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
