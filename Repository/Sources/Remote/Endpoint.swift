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
    case holidays(year: Int, countryCode: String)
    
    public var subPath: String {
        switch self {
        case .supportCountry: 
            return "api/v3/AvailableCountries"
        case .holidays(let year, let countryCode):
            return "api/v3/PublicHolidays/\(year)/\(countryCode)"
        }
    }
}


// MARK: - AccountAPIEndpoints

public enum AccountAPIEndpoints: Endpoint {
    case info
    
    public var subPath: String {
        switch self {
        case .info:
            return "info"
        }
    }
}


// MARK: - TodoAPIEndpoints

public enum TodoAPIEndpoints: Endpoint {
    case make
    case todo(String)
    case todos
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
    case tags
    case allTags
    
    var subPath: String {
        switch self {
        case .make: return "tag"
        case .tag(let id): return "tag/\(id)"
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
        case let holiday as HolidayAPIEndpoints:
            return "https://date.nager.at/\(holiday.subPath)"
            
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
            
        default: return nil
        }
    }
}
