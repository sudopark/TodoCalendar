//
//  WidgetLink+Extensions.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 1/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import CalendarScenes


extension EventCellViewModel {
    
    var widgetURL: URL? {
        func make(_ path: String, queries: [String: String]) -> URL? {
            let fullPath = "\(AppEnvironment.appScheme)://calendar/event/\(path)"
            var components = URLComponents(string: fullPath)
            components?.queryItems = queries.map {
                URLQueryItem(name: $0.key, value: $0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
            }
            return components?.url
        }
        switch self {
        case let todo as TodoEventCellViewModel:
            return make("todo", queries: [
                "event_id": todo.eventIdentifier
            ])
            
        case let schedule as ScheduleEventCellViewModel:
            let params = schedule.eventTimeRawValue?.queryParams.merging([
                "event_id": schedule.eventIdWithoutTurn
            ]) { $1 }
            return params.flatMap { make("schedule", queries: $0) }
            
        case let holiday as HolidayEventCellViewModel:
            return make("holiday", queries: [
                "event_id": holiday.eventIdentifier
            ])
            
        case let google as GoogleCalendarEventCellViewModel:
            return make("google", queries: [
                "event_id": google.eventIdentifier,
                "calendar_id": google.calendarId
            ])
            
        default: return nil
        }
    }
}
