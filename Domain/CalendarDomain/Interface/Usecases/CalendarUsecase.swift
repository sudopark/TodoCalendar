//
//  CalendarUsecase.swift
//  CalendarDomainInterface
//
//  Created by sudo.park on 10/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


public protocol CalendarUsecase {
    
    var currentDay: AnyPublisher<CalendarComponent.Day, Never> { get }
    
    func components(
        for month: Int, of year: Int
    ) -> AnyPublisher<CalendarComponent, Never>
    
    func getComponents(
        _ year: Int,
        _ month: Int,
        _ startDayOfWeek: DayOfWeeks
    ) throws -> CalendarComponent
}
