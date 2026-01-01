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


enum EventDeepLinkBuilder {
    case todo(id: String)
    case schedule(id: String, time: EventTime)
    case holiday(id: String)
    case google(id: String, calendarId: String)
    
    func build() -> URL? {
        
        func make(_ path: String, queries: [String: String]) -> URL? {
            let fullPath = "\(AppEnvironment.appScheme)://calendar/event/\(path)"
            var components = URLComponents(string: fullPath)
            components?.queryItems = queries.map {
                URLQueryItem(name: $0.key, value: $0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
            }
            return components?.url
        }
        
        switch self {
        case .todo(let id):
            return make("todo", queries: ["event_id": id])
            
        case .schedule(let id, let time):
            let params = time.queryParams.merging(["event_id": id ]) { $1 }
            return make("schedule", queries: params)
            
        case .holiday(let id):
            return make("holiday", queries: ["event_id": id])
            
        case .google(let id, let calendarId):
            return make("google", queries: ["event_id": id, "calendar_id": calendarId])
        }
    }
}


extension EventCellViewModel {
    
    var widgetURL: URL? {
        
        switch self {
        case let todo as TodoEventCellViewModel:
            return EventDeepLinkBuilder.todo(id: todo.eventIdentifier).build()
            
        case let schedule as ScheduleEventCellViewModel:
            return schedule.eventTimeRawValue.flatMap {
                EventDeepLinkBuilder.schedule(id: schedule.eventIdWithoutTurn, time: $0).build()
            }
            
        case let holiday as HolidayEventCellViewModel:
            return EventDeepLinkBuilder.holiday(id: holiday.eventIdentifier).build()
            
        case let google as GoogleCalendarEventCellViewModel:
            return EventDeepLinkBuilder.google(id: google.eventIdentifier, calendarId: google.calendarId).build()
            
        default: return nil
        }
    }
}


extension CalendarDay {
    
    var link: URL? {
        var component = URLComponents(string: "\(AppEnvironment.appScheme)://calendar")
        component?.queryItems = [
            .init(name: "select", value: "\(self.year)_\(self.month.withLeadingZero())_\(self.day.withLeadingZero())")
        ]
        return component?.url
    }
}
