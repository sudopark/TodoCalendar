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
    
    func makeCalendarUsecase() -> any CalendarUsecase
    func makeCalendarSettingUsecase() -> any CalendarSettingUsecase
    func makeHolidayUsecase() -> any HolidayUsecase
}

public protocol EventUsecaseFactory {
 
    func makeTodoEventUsecase() -> any TodoEventUsecase
    func makeScheduleEventUsecase() -> any ScheduleEventUsecase
    func makeEventTagUsecase() -> any EventTagUsecase
    func makeEventTagListUsecase() -> any EventTagListUsecase
}

public protocol UsecaseFactory: CalendarUsecaseFactory, EventUsecaseFactory { }
