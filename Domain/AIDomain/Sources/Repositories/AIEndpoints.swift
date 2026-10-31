//
//  AIEndpoints.swift
//  AIDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface
import AIDomainInterface


// MARK: - AI

public enum AIAPIEndpoints: Endpoint {
    case command
    case interpretCommand
    case confirmCommand
    case rejectCommand
    case cancelCommand
    case job(id: String)
    case usage

    public var host: EndpointHost {
        return .calendarAPI(path: "v1/ai")
    }
    
    public var subPath: String {
        switch self {
        case .command: return "command"
        case .interpretCommand: return "command/interpret"
        case .confirmCommand: return "command/confirm"
        case .rejectCommand: return "command/reject"
        case .cancelCommand: return "command/cancel"
        case .job(let id): return "jobs/\(id)"
        case .usage: return "usage"
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .calendarAPI
    }
}
