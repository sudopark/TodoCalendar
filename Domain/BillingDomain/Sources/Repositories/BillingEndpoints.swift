//
//  BillingEndpoints.swift
//  BillingDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface
import BillingDomainInterface


// MARK: - Billing

public enum BillingAPIEndpoints: Endpoint {
    case plans
    case topups
    case purchases
    case transactions
    case userPlan

    public var host: EndpointHost {
        return .calendarAPI(path: "v1/billing")
    }
    
    public var subPath: String {
        switch self {
        case .plans: return "plans"
        case .topups: return "topups"
        case .purchases: return "purchases"
        case .transactions: return "transactions"
        case .userPlan: return "user-plan"
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .calendarAPI
    }
}


// MARK: - AppPolicy

public enum AppPolicyEndpoints: Endpoint {
    case appPolicy

    public var host: EndpointHost {
        return .external("https://raw.githubusercontent.com/sudopark/TodoCalendar-Terms/main/app-config")
    }

    public var subPath: String {
        switch self {
        case .appPolicy: return "app-policy.json"
        }
    }

    public var authorization: EndpointAuthorization {
        return .none
    }
}
