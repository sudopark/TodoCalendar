//
//  ScheduleEventRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/05/01.
//

import Foundation
import Combine


public protocol ScheduleEventRepository {
    
    func makeScheduleEvent(_ params: ScheduleMakeParams) async throws -> ScheduleEvent
    
    func loadScheduleEvents(in range: Range<TimeStamp>) -> AnyPublisher<[ScheduleEvent], Error>
}
