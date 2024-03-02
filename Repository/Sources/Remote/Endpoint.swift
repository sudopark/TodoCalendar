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
            return "AvailableCountries"
        case .holidays(let year, let countryCode): 
            return "PublicHolidays/\(year)/\(countryCode)"
        }
    }
}

public enum AccountAPIEndpoints: Endpoint {
    case account
    
    public var subPath: String {
        switch self {
        case .account:
            return "account"
        }
    }
}

public enum TodoAPIEndpoints: Endpoint {
    case currentTodo
    
    public var subPath: String {
        switch self {
        case .currentTodo:
            return "current"
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
            return "https://date.nager.at/api/v3/\(holiday.subPath)"
        case let account as AccountAPIEndpoints:
            return "\(calendarAPIHost)/accounts/\(account.subPath)"
        case let todo as TodoAPIEndpoints:
            return "\(calendarAPIHost)/toods/\(todo.subPath)"
        default: return nil
        }
    }
}
