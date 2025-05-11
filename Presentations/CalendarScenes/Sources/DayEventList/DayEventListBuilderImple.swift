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
        let calendarSettingUsecase = self.usecaseFactory.makeCalendarSettingUsecase()
        let todoEventUsecase = self.usecaseFactory.makeTodoEventUsecase()
        let foremostEventUsecase = self.usecaseFactory.makeForemostEventUsecase()
        let uiSettingUsecase = self.usecaseFactory.makeUISettingUsecase()
        let eventListUsecase = CalendarEventListhUsecaseImple(
            todoUsecase: todoEventUsecase,
            scheduleUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase(),
            foremostEventUsecase: foremostEventUsecase,
            calendarSettingUsecase: calendarSettingUsecase,
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase(),
            uiSettingUsecase: uiSettingUsecase
        )
        let viewModel = DayEventListViewModelImple(
            calendarUsecase: usecaseFactory.makeCalendarUsecase(),
            calendarSettingUsecase: calendarSettingUsecase,
            eventListUsecase: eventListUsecase,
            todoEventUsecase: todoEventUsecase,
            foremostEventUsecase: foremostEventUsecase,
            uiSettingUsecase: uiSettingUsecase
        )
        let router = DayEventListRouter(
            eventDetailSceneBuilder: self.eventDetailSceneBuilder,
            eventListSceneBuilder: self.eventListSceneBuilder
        )
        viewModel.router = router
        return .init(viewModel: viewModel, router: router)
    }
}
