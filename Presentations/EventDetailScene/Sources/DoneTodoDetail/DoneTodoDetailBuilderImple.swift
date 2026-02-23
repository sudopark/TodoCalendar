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
    private let selectMapSceneBuilder: any SelectMapAppDialogSceneBuiler
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        selectMapSceneBuilder: any SelectMapAppDialogSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.selectMapSceneBuilder = selectMapSceneBuilder
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
            doneDetailUsecase: usecaseFactory.makeDoneTodoDetailDataUsecase(),
            eventTagUsecase: usecaseFactory.makeEventTagUsecase(),
            calendarSettingUsecase: usecaseFactory.makeCalendarSettingUsecase(),
            uiSettingUsecase: usecaseFactory.makeUISettingUsecase(),
            eventSettingUsecase: usecaseFactory.makeEventSettingUsecase()
        )
        viewModel.listener = listener
        
        let viewController = DoneTodoDetailViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
    
        let router = DoneTodoDetailRouter(
            selectMapSceneBuilder: self.selectMapSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
