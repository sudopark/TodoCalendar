//
//  
//  DoneTodoDetailBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 2/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - DoneTodoDetailSceneBuilerImple

final class DoneTodoDetailSceneBuilerImple {
    
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


extension DoneTodoDetailSceneBuilerImple: DoneTodoDetailSceneBuiler {
    
    @MainActor
    func makeDoneTodoDetailScene(
        uuid: String,
        listener: (any DoneTodoDetailSceneListener)?
    ) -> any DoneTodoDetailScene {
        
        let viewModel = DoneTodoDetailViewModelImple(
            uuid: uuid,
            todoEventUsecase: usecaseFactory.makeTodoEventUsecase(),
            doneDetailUsecase: usecaseFactory.makeEventDetailDataUsecase(),
            eventTagUsecase: usecaseFactory.makeEventTagUsecase(),
            calendarSettingUsecase: usecaseFactory.makeCalendarSettingUsecase(),
            uiSettingUsecase: usecaseFactory.makeUISettingUsecase()
        )
        viewModel.listener = listener
        
        let viewController = DoneTodoDetailViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = DoneTodoDetailRouter(
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
