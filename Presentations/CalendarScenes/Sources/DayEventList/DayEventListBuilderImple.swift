//
//  
//  DayEventListBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - DayEventListSceneBuilerImple

final class DayEventListSceneBuilerImple {

    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let eventDetailSceneBuilder: any EventDetailSceneBuilder
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        eventDetailSceneBuilder: any EventDetailSceneBuilder
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.eventDetailSceneBuilder = eventDetailSceneBuilder
    }
}


extension DayEventListSceneBuilerImple: DayEventListSceneBuiler {
    
    @MainActor
    func makeDayEventListScene() -> any DayEventListScene {
        
        let viewModel = DayEventListViewModelImple(
            calendarSettingUsecase: usecaseFactory.makeCalendarSettingUsecase(),
            todoEventUsecase: usecaseFactory.makeTodoEventUsecase(),
            eventTagUsecase: usecaseFactory.makeEventTagUsecase(),
            uiSettingUsecase: usecaseFactory.makeUISettingUsecase()
        )
        
        let viewController = DayEventListViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        
        let router = DayEventListRouter(
            eventDetailSceneBuilder: self.eventDetailSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
