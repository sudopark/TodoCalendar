//
//  Endpoint.swift
//  Repository
//
//  Created by sudo.park on 2/25/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - Endpoint

public protocol Endpoint: Sendable {
    
    var subPath: String { get }
}


// MARK: - HolidayAPIEndpoints

public enum HolidayAPIEndpoints: Endpoint {
    case supportCountry
    case holidays
    
    public var subPath: String {
        switch self {
        case .supportCountry: 
            return "31ca6b64687c1436ca7e5f705017071a/raw/251dd3885ab5b7ac112140e7b0e6a542fe2901f5/google_calendar_country"
            
        case .holidays:
            return ""
        }
    }
}


// MARK: - AccountAPIEndpoints

public enum AccountAPIEndpoints: Endpoint {
    case info
    case account
    
    public var subPath: String {
        switch self {
        case .info:
            return "info"
        case .account:
            return "account"
        }
    }
}


// MARK: - TodoAPIEndpoints

public enum TodoAPIEndpoints: Endpoint {
    case make
    case todo(String)
    case todos
    case uncompleteds
    case currentTodo
    case done(String)
    case dones
    case revertDone(String)
    case replaceRepeating(String)
    case cancelDone
    
    public var subPath: String {
        switch self {
        case .make:
            return "todo"
            
        case .todo(let id):
            return "todo/\(id)"
            
        case .todos:
            return ""
            
        case .uncompleteds:
            return "uncompleted"
            
        case .currentTodo:
            return ""
            
        case .done(let id):
            return "todo/\(id)/complete"
            
        case .dones:
            return "dones"
            
        case .revertDone(let id):
            return "dones/\(id)/revert"
            
        case .replaceRepeating(let id):
            return "todo/\(id)/replace"
            
        case .cancelDone:
            return "dones/cancel"
        }
    }
}


// MARK: - ScheduleEventEndpoints

enum ScheduleEventEndpoints: Endpoint {
    case make
    case schedule(id: String)
    case exclude(id: String)
    case branchRepeating(id: String)
    case schedules
    
    var subPath: String {
        switch self {
        case .make: return "schedule"
        case .schedule(let id): return "schedule/\(id)"
        case .exclude(let id): return "schedule/\(id)/exclude"
        case .branchRepeating(id: let id): return "schedule/\(id)/branch_repeating"
        case .schedules: return ""
        }
    }
}

// MARK: - ForemostEventEndpoints

enum ForemostEventEndpoints: Endpoint {
    case event
    
    var subPath: String {
        switch self {
        case .event:
            return "event"
        }
    }
}

// MARK: - EventTag

enum EventTagEndpoints: Endpoint {
    case make
    case tag(id: String)
    case tagAndEvents(id: String)
    case tags
    case allTags
    
    var subPath: String {
        switch self {
        case .make: return "tag"
        case .tag(let id): return "tag/\(id)"
        case .tagAndEvents(id: let id): return "tag_and_events/\(id)"
        case .tags: return ""
        case .allTags: return "all"
        }
    }
}


// MARK: - event detail

enum EventDetailEndpoints: Endpoint {
    case detail(eventId: String)
    
    var subPath: String {
        switch self {
        case .detail(let eventId): return "\(eventId)"
        }
    }
}

// MARK: - AppSetting

enum AppSettingEndpoints: Endpoint {
    case defaultEventTagColor
    
    var subPath: String {
        switch self {
        case .defaultEventTagColor: return "event/tag/default/color"
        }
    }
}

// MARK: - migration

enum MigrationEndpoints: Endpoint {
    case eventTags
    case todos
    case schedules
    case eventDetails
    case doneTodos
    
    var subPath: String {
        switch self {
        case .eventTags: return "event_tags"
        case .todos: return "todos"
        case .schedules: return "schedules"
        case .eventDetails: return "event_details"
        case .doneTodos: return "todos/done"
        }
    }
}

enum FeedbackEndpoints: Endpoint {
    case post
    
    var subPath: String {
        switch self {
        case .post: return ""
        }
    }
}

// MARK: - google account endpoint

enum GoogleAuthEndpoint: Endpoint {
    case token
    
    var subPath: String {
        switch self {
        case .token: return "token"
        }
    }
}

// MARK: - google calendar endpoint

enum GoogleCalendarEndpoint: Endpoint {
    case colors
    case calednarList
    case eventList(calendarId: String)
    case event(calendarId: String, eventId: String)
    
    var subPath: String {
        switch self {
        case .colors: 
            return "colors"
        case .calednarList: 
            return "users/me/calendarList"
        case .eventList(let calendarId): 
            return "calendars/\(calendarId)/events"
        case .event(let calendarId, let eventId):
            return "calendars/\(calendarId)/events/\(eventId)"
        }
    }
}


// MARK: - RemoteEnvironment

public struct RemoteEnvironment: Sendable {
    
    let calendarAPIHost: String
    private let csAPI: String
    public init(
        calendarAPIHost: String,
        csAPI: String
    ) {
        self.calendarAPIHost = calendarAPIHost
        self.csAPI = csAPI
    }
    
    func path(_ endpoint: any Endpoint) -> String? {
        
        func appendSubpathIfNotEmpty(_ prefix: String, _ subPath: String) -> String {
            return subPath.isEmpty ? prefix : "\(prefix)/\(subPath)"
        }
        
        switch endpoint {
        case .supportCountry as HolidayAPIEndpoints:
            return "https://gist.githubusercontent.com/sudopark/\(endpoint.subPath)"
            
        case let holiday as HolidayAPIEndpoints:
            let prefix = "\(calendarAPIHost)/v1/holiday"
            return appendSubpathIfNotEmpty(prefix, endpoint.subPath)
            
        case let account as AccountAPIEndpoints:
            return "\(calendarAPIHost)/v1/accounts/\(account.subPath)"
            
        case let todo as TodoAPIEndpoints:
            let prefix = "\(calendarAPIHost)/v1/todos"
            return appendSubpathIfNotEmpty(prefix, todo.subPath)
            
        case let schedule as ScheduleEventEndpoints:
            let prefix = "\(calendarAPIHost)/v1/schedules"
            return appendSubpathIfNotEmpty(prefix, schedule.subPath)
            
        case let foremost as ForemostEventEndpoints:
            let prefix = "\(calendarAPIHost)/v1/foremost"
            return appendSubpathIfNotEmpty(prefix, foremost.subPath)
            
        case let eventTag as EventTagEndpoints:
            let prefix = "\(calendarAPIHost)/v1/tags"
            return appendSubpathIfNotEmpty(prefix, eventTag.subPath)
            
        case let detail as EventDetailEndpoints:
            let prefix = "\(calendarAPIHost)/v1/event_details"
            return appendSubpathIfNotEmpty(prefix, detail.subPath)
            
        case let setting as AppSettingEndpoints:
            let prefix = "\(calendarAPIHost)/v1/setting"
            return appendSubpathIfNotEmpty(prefix, setting.subPath)
            
        case let migration as MigrationEndpoints:
            let prefix = "\(calendarAPIHost)/v1/migration"
            return appendSubpathIfNotEmpty(prefix, migration.subPath)
            
        case let feedback as FeedbackEndpoints:
            return appendSubpathIfNotEmpty(self.csAPI, feedback.subPath)
            
        case let googleAuth as GoogleAuthEndpoint:
            return appendSubpathIfNotEmpty("https://oauth2.googleapis.com", googleAuth.subPath)
            
        case let googleCalendar as GoogleCalendarEndpoint:
            let prefix = "https://www.googleapis.com/calendar/v3"
            return appendSubpathIfNotEmpty(prefix, googleCalendar.subPath)
            
        default: return nil
        }
    }
}
