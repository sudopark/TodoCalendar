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
        
        let singleMonthSceneBuilder = SingleMonthSceneBuilderImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        let router = CalendarViewRouterImple(singleMonthSceneBuilder)
        router.scene = viewController
        viewModel.router = router
        
        return viewController
    }
}
