//
//  AccountEndpoints.swift
//  AccountDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface
import AccountDomainInterface


// MARK: - AccountAPIEndpoints

public enum AccountAPIEndpoints: Endpoint {
    case info
    case account
    
    public var host: EndpointHost {
        return .calendarAPI(path: "v2/accounts")
    }
    
    public var subPath: String {
        switch self {
        case .info:
            return "info"
        case .account:
            return "account"
        }
    }
    
    public var authorization: EndpointAuthorization {
        switch self {
        case .info: return .none
        case .account: return .none
        }
    }
}
