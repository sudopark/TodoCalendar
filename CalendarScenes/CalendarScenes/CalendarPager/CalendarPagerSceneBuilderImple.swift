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
        
    private let usecaseFactory: UsecaseFactory
    
    public init(
        usecaseFactory: UsecaseFactory
    ) {
        self.usecaseFactory = usecaseFactory
    }
}

extension CalendarSceneBuilderImple: CalendarSceneBuilder {
    
    public func makeCalendarScene() -> any CalendarScene {
        
        let viewModel = CalendarViewModelImple(
            calendarUsecase: self.usecaseFactory.makeCalendarUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            holidayUsecase: self.usecaseFactory.makeHolidayUsecase(),
            todoEventUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleEventUsecase: self.usecaseFactory.makeScheduleEventUsecase()
        )
        let viewController = CalendarViewController(viewModel: viewModel)
        
        let nextSceneBuilder = SingleMonthSceneBuilderImple(
            usecaseFactory: self.usecaseFactory
        )
        let router = CalendarViewRouterImple(nextSceneBuilder)
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
