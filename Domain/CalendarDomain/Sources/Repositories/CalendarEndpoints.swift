//
//  CalendarEndpoints.swift
//  CalendarDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface
import CalendarDomainInterface


// MARK: - HolidayAPIEndpoints

public enum HolidayAPIEndpoints: Endpoint {
    case supportCountry
    case holidays
    
    public var host: EndpointHost {
        switch self {
        case .supportCountry: return .external("https://gist.githubusercontent.com/sudopark")
        case .holidays: return .calendarAPI(path: "v2/holiday")
        }
    }
    
    public var subPath: String {
        switch self {
        case .supportCountry: 
            return "31ca6b64687c1436ca7e5f705017071a/raw/251dd3885ab5b7ac112140e7b0e6a542fe2901f5/google_calendar_country"
            
        case .holidays:
            return ""
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .none
    }
}
