//
//  
//  EventTagListBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 2023/09/24.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - EventTagListSceneBuilerImple

final class EventTagListSceneBuilerImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let settingSceneBuilder: any EventSettingSceneBuiler
    private let tagDetailSceneBuilder: any EventTagDetailSceneBuiler
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        settingSceneBuilder: any EventSettingSceneBuiler,
        tagDetailSceneBuilder: any EventTagDetailSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.settingSceneBuilder = settingSceneBuilder
        self.tagDetailSceneBuilder = tagDetailSceneBuilder
    }
}


extension EventTagListSceneBuilerImple: EventTagListSceneBuiler {
    
    @MainActor
    func makeEventTagListScene(
        hasNavigation: Bool,
        listener: (any EventTagListSceneListener)?
    ) -> any EventTagListScene {
        
        let viewModel = EventTagListViewModelImple(
            tagUsecase: self.usecaseFactory.makeEventTagUsecase(),
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase()
        )
        
        let viewController = EventTagListViewController(
            hasNavigation: hasNavigation,
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = EventTagListRouter(
            hasNavigation: hasNavigation,
            eventSettingSceneBuilder: self.settingSceneBuilder,
            tagDetailSceneBuilder: self.tagDetailSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        viewModel.listener = listener
        
        return viewController
    }
}
