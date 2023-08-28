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
        
    private let usecaseFactory: UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    public init(
        usecaseFactory: UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}

extension CalendarSceneBuilderImple: CalendarSceneBuilder {
    
    public func makeCalendarScene(
        listener: CalendarSceneListener?
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
            viewAppearance: self.viewAppearance
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
