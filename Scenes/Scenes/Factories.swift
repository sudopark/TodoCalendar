//
//  Factories.swift
//  Scenes
//
//  Created by sudo.park on 2023/08/01.
//

import Foundation
import Domain

// MARK: - Usecase Factory

public protocol CalendarUsecaseFactory {
    
    func makeCalendarUsecase() -> CalendarUsecase
    func makeCalendarSettingUsecase() -> CalendarSettingUsecase
    func makeHolidayUsecase() -> HolidayUsecase
}

public protocol EventUsecaseFactory {
 
    func makeTodoEventUsecase() -> TodoEventUsecase
    func makeScheduleEventUsecase() -> ScheduleEventUsecase
    func makeEventTagUsecase() -> EventTagUsecase
}

public protocol UsecaseFactory: CalendarUsecaseFactory, EventUsecaseFactory { }
