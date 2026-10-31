//
//  DaysIntervalCountUsecase.swift
//  EventDomainInterface
//
//  Created by sudo.park on 10/20/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import CalendarDomainInterface

public protocol DaysIntervalCountUsecase: Sendable {
    
    func countDays(to eventTime: EventTime) -> AnyPublisher<Int, Never>
    func countDays(to holiday: Holiday) -> AnyPublisher<Int, Never>
}

extension DaysIntervalCountUsecase {
    
    public func countDays(to date: Date) -> AnyPublisher<Int, Never> {
        return self.countDays(to: .at(date.timeIntervalSince1970))
    }
}
