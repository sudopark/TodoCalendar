//
//  ExternalCalendarEndpoints.swift
//  ExternalCalendarDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface
import ExternalCalendarDomainInterface


// MARK: - google calendar endpoint

public enum GoogleCalendarEndpoint: Endpoint {
    case colors
    case calednarList
    case eventList(calendarId: String)
    case event(calendarId: String, eventId: String)
    case eventInstances(calendarId: String, eventId: String)

    public var host: EndpointHost {
        return .external("https://www.googleapis.com/calendar/v3")
    }
    
    public var subPath: String {
        switch self {
        case .colors:
            return "colors"
        case .calednarList:
            return "users/me/calendarList"
        case .eventList(let calendarId):
            return "calendars/\(calendarId)/events"
        case .event(let calendarId, let eventId):
            return "calendars/\(calendarId)/events/\(eventId)"
        case .eventInstances(let calendarId, let eventId):
            return "calendars/\(calendarId)/events/\(eventId)/instances"
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .google
    }
}
