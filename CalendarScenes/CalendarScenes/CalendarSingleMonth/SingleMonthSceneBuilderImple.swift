//
//  SingleMonthSceneBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain
import Scenes


public final class SingleMonthSceneBuilderImple {
    
    private let calendarUsecase: CalendarUsecase
    private let calendarSettingUsecase: CalendarSettingUsecase
    private let todoUsecase: TodoEventUsecase
    private let scheduleEventUsecase: ScheduleEventUsecase
    
    public init(
        calendarUsecase: CalendarUsecase,
        calendarSettingUsecase: CalendarSettingUsecase,
        todoUsecase: TodoEventUsecase,
        scheduleEventUsecase: ScheduleEventUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.todoUsecase = todoUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
    }
}


extension SingleMonthSceneBuilderImple: CalendarSingleMonthSceneBuilder {
    
    public func makeSingleMonthScene(_ month: CalendarMonth) -> any CalendarSingleMonthScene {
        
        let viewModel = CalendarSingleMonthViewModelImple(
            calendarUsecase: self.calendarUsecase,
            calendarSettingUsecase: self.calendarSettingUsecase,
            todoUsecase: self.todoUsecase,
            scheduleEventUsecase: self.scheduleEventUsecase
        )
        // TODO: setup router
        let viewController = SingleMonthViewController(viewModel: viewModel)
        return viewController
    }
}
