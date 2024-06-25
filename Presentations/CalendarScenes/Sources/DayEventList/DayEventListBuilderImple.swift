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
    private let eventListSceneBuilder: any EventListSceneBuiler
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        eventDetailSceneBuilder: any EventDetailSceneBuilder,
        eventListSceneBuilder: any EventListSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.eventDetailSceneBuilder = eventDetailSceneBuilder
        self.eventListSceneBuilder = eventListSceneBuilder
    }
}


extension DayEventListSceneBuilerImple: DayEventListSceneBuiler {
    
    func makeSceneComponent() -> DayEventListSceneComponent {
        let viewModel = DayEventListViewModelImple(
            calendarSettingUsecase: usecaseFactory.makeCalendarSettingUsecase(),
            todoEventUsecase: usecaseFactory.makeTodoEventUsecase(),
            scheduleEventUsecase: usecaseFactory.makeScheduleEventUsecase(),
            foremostEventUsecase: usecaseFactory.makeForemostEventUsecase(),
            eventTagUsecase: usecaseFactory.makeEventTagUsecase(),
            uiSettingUsecase: usecaseFactory.makeUISettingUsecase()
        )
        let router = DayEventListRouter(
            eventDetailSceneBuilder: self.eventDetailSceneBuilder,
            eventListSceneBuilder: self.eventListSceneBuilder
        )
        viewModel.router = router
        return .init(viewModel: viewModel, router: router)
    }
}
