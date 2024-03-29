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

public enum AccountAPIEndpoints: Endpoint {
    case info
    
    public var subPath: String {
        switch self {
        case .info:
            return "info"
        }
    }
}

public enum TodoAPIEndpoints: Endpoint {
    case make
    case todo(String)
    case todos
    case currentTodo
    case done(String)
    case replaceRepeating(String)
    
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
            
        case .replaceRepeating(let id):
            return "todo/\(id)/replace"
        }
    }
}

// MARK: - RemoteEnvironment

public struct RemoteEnvironment: Sendable {
    
    let calendarAPIHost: String
    public init(
        calendarAPIHost: String
    ) {
        self.calendarAPIHost = calendarAPIHost
    }
    
    func path(_ endpoint: any Endpoint) -> String? {
        
        switch endpoint {
        case let holiday as HolidayAPIEndpoints:
            return "https://date.nager.at/\(holiday.subPath)"
        case let account as AccountAPIEndpoints:
            return "\(calendarAPIHost)/accounts/\(account.subPath)"
        case let todo as TodoAPIEndpoints:
            let prefix = "\(calendarAPIHost)/todos"
            let subpath = todo.subPath
            return subpath.isEmpty ? prefix : "\(prefix)/\(subpath)"
        default: return nil
        }
    }
}
