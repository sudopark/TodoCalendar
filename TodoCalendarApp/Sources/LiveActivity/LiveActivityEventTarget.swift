//
//  LiveActivityEventTarget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


enum LiveActivityEventTarget: Codable, Hashable, Sendable {

    case todo(id: String)
    /// 반복 일정일 때만 채운다(EventTime.customKey) — nil이면 비반복.
    case schedule(id: String, turnKey: String?)
    case holiday(uuid: String, dateString: String)
    case googleCalendar(accountId: String, calendarId: String, eventId: String)
    case appleCalendar(calendarId: String, eventId: String)
}
