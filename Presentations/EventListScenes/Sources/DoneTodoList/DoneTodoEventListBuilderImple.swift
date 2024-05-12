//
//  
//  DoneTodoEventListBuilderImple.swift
//  EventListScenes
//
//  Created by sudo.park on 5/11/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - DoneTodoEventListSceneBuilerImple

final class DoneTodoEventListSceneBuilerImple {
    
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


extension DoneTodoEventListSceneBuilerImple: DoneTodoEventListSceneBuiler {
    
    @MainActor
    func makeDoneTodoEventListScene() -> any DoneTodoEventListScene {
        
        let viewModel = DoneTodoEventListViewModelImple(
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            pagingUsecase: self.usecaseFactory.makeDoneTodoPagingUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            uiSettingUsecase: self.usecaseFactory.makeUISettingUsecase()
        )
        
        let viewController = DoneTodoEventListViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = DoneTodoEventListRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
