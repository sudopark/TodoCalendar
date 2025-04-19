//
//  GoogleCalendarRepository.swift
//  Domain
//
//  Created by sudo.park on 2/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine

public protocol GoogleCalendarRepository: Sendable {
    
    func loadColors() -> AnyPublisher<GoogleCalendar.Colors, any Error>
    
    func loadCalendarTags() -> AnyPublisher<[GoogleCalendar.Tag], any Error>
    
    func loadEvents(
        _ calendarId: String,
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[GoogleCalendar.Event], any Error>
    
    func loadEventDetail(
        _ calendarId: String, _ eventId: String
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error>
}
