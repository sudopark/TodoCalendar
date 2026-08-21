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
import AdService


// MARK: - MainSceneBuilerImple

public final class MainSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let calendarSceneBulder: any CalendarSceneBuilder
    private let settingSceneBuilder: any SettingSceneBuiler
    private let mobileAdService: GoogleMobileAdsServiceImple?
    
    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        calendarSceneBulder: any CalendarSceneBuilder,
        settingSceneBuilder: any SettingSceneBuiler,
        mobileAdService: GoogleMobileAdsServiceImple?
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.calendarSceneBulder = calendarSceneBulder
        self.settingSceneBuilder = settingSceneBuilder
        self.mobileAdService = mobileAdService
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
            eventLiveActivityUsecase: self.usecaseFactory.eventLiveActivityUsecase
        )
        
        let viewController = MainViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance,
            mobileAdService: self.mobileAdService
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
