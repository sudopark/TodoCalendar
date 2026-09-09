//
//  EventDeepLink.swift
//  Domain
//
//  Created by sudo.park on 1/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum EventDeepLinkBuilder {
    case todo(id: String)
    case schedule(id: String, time: EventTime)
    case holiday(id: String)
    case google(id: String, calendarId: String, accountId: String)
    case apple(id: String, calendarId: String)

    public func build() -> URL? {
        
        func make(_ path: String, queries: [String: String]) -> URL? {
            let fullPath = "\(AppDeepLink.scheme)://calendar/event/\(path)"
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
            
        case .google(let id, let calendarId, let accountId):
            return make("google", queries: ["event_id": id, "calendar_id": calendarId, "account_id": accountId])

        case .apple(let id, let calendarId):
            return make("apple", queries: ["event_id": id, "calendar_id": calendarId])
        }
    }
}


extension CalendarDay {

    public var link: URL? {
        var component = URLComponents(string: "\(AppDeepLink.scheme)://calendar")
        component?.queryItems = [
            .init(name: "select", value: "\(self.year)_\(self.month.withLeadingZero())_\(self.day.withLeadingZero())")
        ]
        return component?.url
    }
}


public enum AICommandEntryLink {
    public static var url: URL? {
        return URL(string: "\(AppDeepLink.scheme)://calendar/ai")
    }
}
