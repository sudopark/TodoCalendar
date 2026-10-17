//
//  EventCellViewModel+WidgetURL.swift
//  CalendarPresentation
//
//  Created by sudo.park on 1/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


extension EventCellViewModel {
    
    public var widgetURL: URL? {
        
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
            return EventDeepLinkBuilder.google(id: google.eventIdentifier, calendarId: google.calendarId, accountId: google.accountId).build()

        case let apple as AppleCalendarEventCellViewModel:
            return EventDeepLinkBuilder.apple(id: apple.eventIdentifier, calendarId: apple.calendarId).build()

        default: return nil
        }
    }
}
