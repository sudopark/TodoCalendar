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
        let calendarSettingUsecase = self.usecaseFactory.makeCalendarSettingUsecase()
        let tagUsecase = self.usecaseFactory.makeEventTagUsecase()
        let uiSettingUsecase = self.usecaseFactory.makeUISettingUsecase()
        let eventListUsecase = CalendarEventListhUsecaseImple(
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase(),
            foremostEventUsecase: self.usecaseFactory.makeForemostEventUsecase(),
            calendarSettingUsecase: calendarSettingUsecase,
            eventTagUsecase: tagUsecase,
            uiSettingUsecase: uiSettingUsecase
        )
        let viewModel = MonthViewModelImple(
            initialMonth: month,
            calendarUsecase: self.usecaseFactory.makeCalendarUsecase(),
            calendarSettingUsecase: calendarSettingUsecase,
            eventListUsecase: eventListUsecase,
            eventTagUsecase: tagUsecase,
            uiSettingUsecase: uiSettingUsecase
        )
        return .init(viewModel: viewModel)
    }
}
