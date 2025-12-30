//
//  
//  SettingItemListBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 11/21/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - SettingItemListSceneBuilerImple

final class SettingItemListSceneBuilerImple {
    
    private let appstoreLinkPath: String
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let appearanceSceneBuilder: any AppearanceSettingSceneBuiler
    private let eventSettingSceneBuilder: any EventSettingSceneBuiler
    private let holidayListSceneBuilder: any HolidayListSceneBuiler
    private let memberSceneBuilder: any MemberSceneBuilder
    private let feedbackPostSceneBuiler: any FeedbackPostSceneBuiler
    
    init(
        appstoreLinkPath: String,
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        appearanceSceneBuilder: any AppearanceSettingSceneBuiler,
        eventSettingSceneBuilder: any EventSettingSceneBuiler,
        holidayListSceneBuilder: any HolidayListSceneBuiler,
        memberSceneBuilder: any MemberSceneBuilder,
        feedbackPostSceneBuiler: any FeedbackPostSceneBuiler
    ) {
        self.appstoreLinkPath = appstoreLinkPath
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.appearanceSceneBuilder = appearanceSceneBuilder
        self.eventSettingSceneBuilder = eventSettingSceneBuilder
        self.holidayListSceneBuilder = holidayListSceneBuilder
        self.memberSceneBuilder = memberSceneBuilder
        self.feedbackPostSceneBuiler = feedbackPostSceneBuiler
    }
}


extension SettingItemListSceneBuilerImple: SettingItemListSceneBuiler {
    
    @MainActor
    func makeSettingItemListScene() -> any SettingItemListScene {
        
        let viewModel = SettingItemListViewModelImple(
            appstoreLinkPath: self.appstoreLinkPath,
            accountUsecase: self.usecaseFactory.accountUescase,
            uiSettingUsecase: self.usecaseFactory.makeUISettingUsecase(),
            deviceInfoFetchService: self.usecaseFactory.deviceInfoFetchService()
        )
        
        let viewController = SettingItemListViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = SettingItemListRouter(
            appearanceSceneBuilder: self.appearanceSceneBuilder,
            eventSettingSceneBuilder: self.eventSettingSceneBuilder,
            holidayListSceneBuilder: self.holidayListSceneBuilder,
            memberSceneBuilder: self.memberSceneBuilder,
            feedbackPostSceneBuiler: self.feedbackPostSceneBuiler
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
