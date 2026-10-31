//
//  MigrationEndpoints.swift
//  MigrationDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface
import MigrationDomainInterface


// MARK: - migration

public enum MigrationEndpoints: Endpoint {
    case eventTags
    case todos
    case schedules
    case eventDetails
    case doneTodos
    case doneTodoDetails
    case customColorThemes
    
    public var host: EndpointHost {
        return .calendarAPI(path: "v2/migration")
    }
    
    public var subPath: String {
        switch self {
        case .eventTags: return "event_tags"
        case .todos: return "todos"
        case .schedules: return "schedules"
        case .eventDetails: return "event_details"
        case .doneTodos: return "todos/done"
        case .doneTodoDetails: return "todos/done/details"
        case .customColorThemes: return "color_themes"
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .calendarAPI
    }
}
