//
//  EventEndpoints.swift
//  EventDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface
import EventDomainInterface


// MARK: - TodoAPIEndpoints

public enum TodoAPIEndpoints: Endpoint {
    case make
    case todo(String)
    case todos
    case uncompleteds
    case currentTodo
    case complete(String)
    case done(String)
    case dones
    case revertDone(String)
    case replaceRepeating(String)
    case cancelDone
    
    public var host: EndpointHost {
        return .calendarAPI(path: "v2/todos")
    }
    
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
            
        case .complete(let id):
            return "todo/\(id)/complete"
            
        case .done(let id):
            return "dones/\(id)"
            
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
    
    public var authorization: EndpointAuthorization {
        return .calendarAPI
    }
}


// MARK: - ScheduleEventEndpoints

public enum ScheduleEventEndpoints: Endpoint {
    case make
    case schedule(id: String)
    case exclude(id: String)
    case branchRepeating(id: String)
    case schedules
    
    public var host: EndpointHost {
        return .calendarAPI(path: "v2/schedules")
    }
    
    public var subPath: String {
        switch self {
        case .make: return "schedule"
        case .schedule(let id): return "schedule/\(id)"
        case .exclude(let id): return "schedule/\(id)/exclude"
        case .branchRepeating(id: let id): return "schedule/\(id)/branch_repeating"
        case .schedules: return ""
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .calendarAPI
    }
}

// MARK: - ForemostEventEndpoints

public enum ForemostEventEndpoints: Endpoint {
    case event
    
    public var host: EndpointHost {
        return .calendarAPI(path: "v2/foremost")
    }
    
    public var subPath: String {
        switch self {
        case .event:
            return "event"
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .calendarAPI
    }
}

// MARK: - EventTag

public enum EventTagEndpoints: Endpoint {
    case make
    case tag(id: String)
    case tagAndEvents(id: String)
    case tagWithEvents(id: String)
    case tags
    case allTags
    
    public var host: EndpointHost {
        return .calendarAPI(path: "v2/tags")
    }
    
    public var subPath: String {
        switch self {
        case .make: return "tag"
        case .tag(let id): return "tag/\(id)"
        case .tagAndEvents(let id): return "tag_and_events/\(id)"
        case .tagWithEvents(let id): return "tag_with_events/\(id)"
        case .tags: return ""
        case .allTags: return "all"
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .calendarAPI
    }
}


// MARK: - event detail

public enum EventDetailEndpoints: Endpoint {
    case detail(eventId: String)
    case doneTodoDetail(eventId: String)
    
    public var host: EndpointHost {
        return .calendarAPI(path: "v2/event_details")
    }
    
    public var subPath: String {
        switch self {
        case .detail(let eventId): return "\(eventId)"
        case .doneTodoDetail(let eventId): return "done/\(eventId)"
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .calendarAPI
    }
}

// MARK: - sync api

public enum EventSyncEndPoints: Endpoint {
    
    case check
    case start
    case `continue`
    
    public var host: EndpointHost {
        return .calendarAPI(path: "v2/sync")
    }
    
    public var subPath: String {
        switch self {
        case .check: return "check"
        case .start: return "start"
        case .continue: return "continue"
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .calendarAPI
    }
}
