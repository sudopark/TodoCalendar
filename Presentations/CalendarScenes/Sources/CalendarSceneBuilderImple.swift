//
//  CalendarSceneBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain
import Scenes
import CommonPresentation

public struct CalendarSceneBuilderImple {
        
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let eventDetailSceneBuilder: any EventDetailSceneBuilder
    private let eventListSceneBuilder: any EventListSceneBuiler
    
    public init(
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

extension CalendarSceneBuilderImple: CalendarSceneBuilder {
    
    @MainActor
    public func makeCalendarScene(
        listener: (any CalendarSceneListener)?
    ) -> any CalendarScene {
        
        let viewModel = CalendarViewModelImple(
            calendarUsecase: self.usecaseFactory.makeCalendarUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            holidayUsecase: self.usecaseFactory.makeHolidayUsecase(),
            todoEventUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleEventUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase()
        )
        viewModel.listener = listener
        let viewController = CalendarViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        
        let monthSceneBuilder = MonthSceneBuilderImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        let eventListSceneBuilder = DayEventListSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            eventDetailSceneBuilder: self.eventDetailSceneBuilder,
            eventListSceneBuilder: self.eventListSceneBuilder
        )
        let paperSceneBuilder = CalendarPaperSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            monthSceneBuilder: monthSceneBuilder,
            eventListSceneBuilder: eventListSceneBuilder
        )
        let router = CalendarViewRouterImple(paperSceneBuilder)
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
