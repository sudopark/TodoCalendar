//
//  MonthSceneBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain
import Scenes
import CommonPresentation


final class MonthSceneBuilderImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension MonthSceneBuilderImple: MonthSceneBuilder {
    
    func makeSceneComponent(_ month: CalendarMonth) -> MonthSceneComponent {
        let viewModel = MonthViewModelImple(
            initialMonth: month,
            calendarUsecase: self.usecaseFactory.makeCalendarUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleEventUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase(),
            uiSettingUsecase: self.usecaseFactory.makeUISettingUsecase()
        )
        return .init(viewModel: viewModel)
    }
}
