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
    
    private let usecaseFactory: UsecaseFactory
    
    public init(
        usecaseFactory: UsecaseFactory
    ) {
        self.usecaseFactory = usecaseFactory
    }
}


extension SingleMonthSceneBuilderImple: SingleMonthSceneBuilder {
    
    public func makeSingleMonthScene(_ month: CalendarMonth) -> any SingleMonthScene {
        
        let viewModel = SingleMonthViewModelImple(
            calendarUsecase: self.usecaseFactory.makeCalendarUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleEventUsecase: self.usecaseFactory.makeScheduleEventUsecase()
        )
        // TODO: setup router
        let viewController = SingleMonthViewController(viewModel: viewModel)
        return viewController
    }
}
