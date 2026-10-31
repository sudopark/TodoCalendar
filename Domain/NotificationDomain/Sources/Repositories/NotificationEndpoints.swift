//
//  NotificationEndpoints.swift
//  NotificationDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface
import NotificationDomainInterface


// MARK: - User

public enum UserAPIEndpoints: Endpoint {
    case notification
    
    public var host: EndpointHost {
        return .calendarAPI(path: "v2/user")
    }
    
    public var subPath: String {
        switch self {
        case .notification: return "notification"
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .calendarAPI
    }
}
