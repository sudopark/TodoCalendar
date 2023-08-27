//
//  SingleMonthSceneBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain
import Scenes
import CommonPresentation


final class SingleMonthSceneBuilderImple {
    
    private let usecaseFactory: UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    init(
        usecaseFactory: UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension SingleMonthSceneBuilderImple: SingleMonthSceneBuilder {
    
    func makeSingleMonthScene(_ month: CalendarMonth) -> any SingleMonthScene {
        
        let viewModel = SingleMonthViewModelImple(
            calendarUsecase: self.usecaseFactory.makeCalendarUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleEventUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase()
        )
        // TODO: setup router
        let viewController = SingleMonthViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        return viewController
    }
}
