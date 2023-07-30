//
//  CalendarSceneBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain
import Scenes

public struct CalendarSceneBuilderImple {
        
    private let calendarUsecase: CalendarUsecase
    private let calendarSettingUsecase: CalendarSettingUsecase
    private let holidayUsecase: HolidayUsecase
    private let todoEventUsecase: TodoEventUsecase
    private let scheduleEventUsecase: ScheduleEventUsecase
    
    public init(
        calendarUsecase: CalendarUsecase,
        calendarSettingUsecase: CalendarSettingUsecase,
        holidayUsecase: HolidayUsecase,
        todoEventUsecase: TodoEventUsecase,
        scheduleEventUsecase: ScheduleEventUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.holidayUsecase = holidayUsecase
        self.todoEventUsecase = todoEventUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
    }
}

extension CalendarSceneBuilderImple: CalendarSceneBuilder {
    
    public func makeCalendarScene() -> any CalendarScene {
        
        let viewModel = CalendarViewModelImple(
            calendarUsecase: self.calendarUsecase,
            calendarSettingUsecase: self.calendarSettingUsecase,
            holidayUsecase: self.holidayUsecase,
            todoEventUsecase: self.todoEventUsecase,
            scheduleEventUsecase: self.scheduleEventUsecase
        )
        let viewController = CalendarViewController(viewModel: viewModel)
        
        let nextSceneBuilder = SingleMonthSceneBuilderImple(calendarUsecase: self.calendarUsecase, calendarSettingUsecase: self.calendarSettingUsecase, todoUsecase: self.todoEventUsecase, scheduleEventUsecase: self.scheduleEventUsecase)
        let router = CalendarViewRouterImple(nextSceneBuilder)
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
