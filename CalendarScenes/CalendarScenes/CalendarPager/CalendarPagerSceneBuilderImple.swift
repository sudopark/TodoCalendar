//
//  CalendarPagerSceneBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain
import Scenes

public struct CalendarPagerSceneBuilderImple {
        
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

extension CalendarPagerSceneBuilderImple: CalendarPagerSceneBuilder {
    
    public func makeCalendarPagerScene() -> any CalendarPagerScene {
        
        let viewModel = CalendarPagerViewModelImple(
            calendarUsecase: self.calendarUsecase,
            calendarSettingUsecase: self.calendarSettingUsecase,
            holidayUsecase: self.holidayUsecase,
            todoEventUsecase: self.todoEventUsecase,
            scheduleEventUsecase: self.scheduleEventUsecase
        )
        let viewController = CalendarPagerViewController(viewModel: viewModel)
        
        let nextSceneBuilder = SingleMonthSceneBuilderImple(calendarUsecase: self.calendarUsecase, calendarSettingUsecase: self.calendarSettingUsecase, todoUsecase: self.todoEventUsecase, scheduleEventUsecase: self.scheduleEventUsecase)
        let router = CalendarPagerViewRouterImple(nextSceneBuilder)
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
