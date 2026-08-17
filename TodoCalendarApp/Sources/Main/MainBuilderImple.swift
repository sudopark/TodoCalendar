//
//  
//  MainBuilderImple.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/26.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - MainSceneBuilerImple

public final class MainSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let sharedDataStore: SharedDataStore
    private let viewAppearance: ViewAppearance
    private let calendarSceneBulder: any CalendarSceneBuilder
    private let settingSceneBuilder: any SettingSceneBuiler
    
    public init(
        usecaseFactory: any UsecaseFactory,
        sharedDataStore: SharedDataStore,
        viewAppearance: ViewAppearance,
        calendarSceneBulder: any CalendarSceneBuilder,
        settingSceneBuilder: any SettingSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.sharedDataStore = sharedDataStore
        self.viewAppearance = viewAppearance
        self.calendarSceneBulder = calendarSceneBulder
        self.settingSceneBuilder = settingSceneBuilder
    }
}


extension MainSceneBuilerImple: MainSceneBuiler {
    
    @MainActor
    public func makeMainScene() -> any MainScene {
        
        let viewModel = MainViewModelImple(
            uiSettingUsecase: self.usecaseFactory.makeUISettingUsecase(),
            temporaryUserDataMigrationUsecase: self.usecaseFactory.temporaryUserDataMigrationUsecase,
            eventNotificationUsecase: self.usecaseFactory.makeEventNotificationUsecase(),
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase(),
            eventNotifyService: self.usecaseFactory.eventNotifyService,
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase(),
            appleCalendarUsecase: self.usecaseFactory.makeAppleCalendarUsecase(),
            eventSyncUsecase: self.usecaseFactory.eventSyncUsecase,
            billingUsecase: self.usecaseFactory.billingUsecase,
            aiAgentOrchestrationUsecase: self.usecaseFactory.aiAgentOrchestrationUsecase,
            eventLiveActivityUsecase: EventLiveActivityUsecaseImple(
                controller: EventCountdownLiveActivityController(),
                sharedDataStore: self.sharedDataStore
            )
        )
        
        let viewController = MainViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        
        let router = MainRouter(
            calendarSceneBulder: self.calendarSceneBulder,
            settingSceneBuilder: self.settingSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
