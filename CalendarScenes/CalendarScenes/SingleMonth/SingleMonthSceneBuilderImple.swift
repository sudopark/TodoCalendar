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


public final class SingleMonthSceneBuilderImple {
    
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


extension SingleMonthSceneBuilderImple: SingleMonthSceneBuilder {
    
    public func makeSingleMonthScene(_ month: CalendarMonth) -> any SingleMonthScene {
        
        let viewModel = SingleMonthViewModelImple(
            calendarUsecase: self.usecaseFactory.makeCalendarUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleEventUsecase: self.usecaseFactory.makeScheduleEventUsecase()
        )
        // TODO: setup router
        let viewController = SingleMonthViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        return viewController
    }
}
