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
    
    public func makeCalendarScene() -> any CalendarScene {
        
        let viewModel = CalendarViewModelImple(
            calendarUsecase: self.usecaseFactory.makeCalendarUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            holidayUsecase: self.usecaseFactory.makeHolidayUsecase(),
            todoEventUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleEventUsecase: self.usecaseFactory.makeScheduleEventUsecase()
        )
        let viewController = CalendarViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        
        let nextSceneBuilder = SingleMonthSceneBuilderImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        let router = CalendarViewRouterImple(nextSceneBuilder)
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}