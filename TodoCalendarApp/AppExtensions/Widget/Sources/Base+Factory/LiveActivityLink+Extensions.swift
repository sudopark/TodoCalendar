//
//  LiveActivityLink+Extensions.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 1/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import CalendarPresentation


extension LiveActivityEventTarget {

    func eventDetailURL(scheduleTimeQuery: [String: String]?) -> URL? {
        switch self {
        case .todo(let id):
            return EventDeepLinkBuilder.todo(id: id).build()

        case .schedule(let id, _):
            return scheduleTimeQuery
                .flatMap { EventTime(deepLink: $0) }
                .flatMap { EventDeepLinkBuilder.schedule(id: id, time: $0).build() }

        case .holiday(let uuid, _):
            return EventDeepLinkBuilder.holiday(id: uuid).build()

        case .googleCalendar(let accountId, let calendarId, let eventId):
            return EventDeepLinkBuilder.google(id: eventId, calendarId: calendarId, accountId: accountId).build()

        case .appleCalendar(let calendarId, let eventId):
            return EventDeepLinkBuilder.apple(id: eventId, calendarId: calendarId).build()
        }
    }
}
