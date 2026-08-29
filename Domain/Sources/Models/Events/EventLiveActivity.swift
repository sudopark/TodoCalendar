//
//  EventLiveActivity.swift
//  Domain
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum LiveActivityTarget: Sendable, Hashable {
    case todo(id: String)
    case schedule(id: String, turnKey: String?)
    case holiday(uuid: String, dateString: String)
    case googleCalendar(accountId: String, calendarId: String, eventId: String)
    case appleCalendar(calendarId: String, eventId: String)
}


public enum EventLiveActivityStartFailReason: Error, Equatable {
    case eventNotFound
    case alreadyPassed
    case tooFarFuture
}
