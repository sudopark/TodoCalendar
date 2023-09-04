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

    private let usecaseFactory: UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    init(
        usecaseFactory: UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension DayEventListSceneBuilerImple: DayEventListSceneBuiler {
    
    func makeDayEventListScene() -> any DayEventListScene {
        
        let viewModel = DayEventListViewModelImple(
            calendarSettingUsecase: usecaseFactory.makeCalendarSettingUsecase(),
            todoEventUsecase: usecaseFactory.makeTodoEventUsecase(),
            scheduleEventUsecase: usecaseFactory.makeScheduleEventUsecase(),
            eventTagUsecase: usecaseFactory.makeEventTagUsecase()
        )
        
        let viewController = DayEventListViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        
        let router = DayEventListRouter()
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
