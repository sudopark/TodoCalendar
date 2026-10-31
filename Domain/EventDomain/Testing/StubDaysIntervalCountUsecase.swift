//
//  StubDaysIntervalCountUsecase.swift
//  EventDomainTesting
//
//  Created by sudo.park on 10/25/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CalendarDomainInterface
import EventDomainInterface


open class StubDaysIntervalCountUsecase: DaysIntervalCountUsecase, @unchecked Sendable {
    
    public init() { }

    public func countDays(to eventTime: EventTime) -> AnyPublisher<Int, Never> {
        return [-4, 0, 4].publisher.eraseToAnyPublisher()
    }
    
    public func countDays(to holiday: Holiday) -> AnyPublisher<Int, Never> {
        return [-4, 0, 4].publisher.eraseToAnyPublisher()
    }
}
