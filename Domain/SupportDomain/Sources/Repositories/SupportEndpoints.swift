//
//  SupportEndpoints.swift
//  SupportDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface
import SupportDomainInterface


public enum FeedbackEndpoints: Endpoint {
    case post
    
    public var host: EndpointHost {
        return .customerService
    }
    
    public var subPath: String {
        switch self {
        case .post: return ""
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .none
    }
}

// MARK: - App

public enum AppEndpoints: Endpoint {
    case updateInfo
    case legalNotice

    public var host: EndpointHost {
        return .external("https://raw.githubusercontent.com/sudopark/TodoCalendar-Terms/main/app-config")
    }
    
    public var subPath: String {
        switch self {
        case .updateInfo:
            return "update-info.json"
        case .legalNotice:
            return "legal-notice.json"
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .none
    }
}
