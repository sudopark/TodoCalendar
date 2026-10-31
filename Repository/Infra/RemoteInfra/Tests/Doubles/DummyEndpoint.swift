//
//  DummyEndpoint.swift
//  RemoteInfraTests
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface


enum DummyEndpoint: Endpoint {
    case calendarAPI
    case calendarAPIWithoutAuthorization
    case calendarAPIRoot
    case customerService
    case external
    case google

    var host: EndpointHost {
        switch self {
        case .calendarAPI, .calendarAPIWithoutAuthorization, .calendarAPIRoot: return .calendarAPI(path: "v2/dummy")
        case .customerService: return .customerService
        case .external: return .external("https://external.example.com")
        case .google: return .external("https://www.googleapis.com/calendar/v3")
        }
    }

    var subPath: String {
        switch self {
        case .calendarAPIRoot: return ""
        default: return "some"
        }
    }

    var authorization: EndpointAuthorization {
        switch self {
        case .calendarAPI: return .calendarAPI
        case .google: return .google
        case .calendarAPIWithoutAuthorization, .calendarAPIRoot, .customerService, .external: return .none
        }
    }
}
