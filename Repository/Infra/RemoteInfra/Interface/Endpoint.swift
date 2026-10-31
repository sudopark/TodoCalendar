//
//  Endpoint.swift
//  RemoteInfraInterface
//
//  Created by sudo.park on 2/25/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - Endpoint

public protocol Endpoint: Sendable {
    
    var host: EndpointHost { get }
    var subPath: String { get }
    var authorization: EndpointAuthorization { get }
}

public enum EndpointHost: Sendable, Equatable {
    case calendarAPI(path: String)
    case customerService
    case external(String)
}

public enum EndpointAuthorization: Sendable, Equatable {
    case none
    case calendarAPI
    case google
}




// MARK: - google account endpoint

public enum GoogleAuthEndpoint: Endpoint {
    case token
    
    public var host: EndpointHost {
        return .external("https://oauth2.googleapis.com")
    }
    
    public var subPath: String {
        switch self {
        case .token: return "token"
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .none
    }
}


// MARK: - RemoteEnvironment

public struct RemoteEnvironment: Sendable {
    
    let calendarAPIHost: String
    private let csAPI: String
    public let deviceId: String
    public let acceptLanguage: @Sendable () -> String
    public init(
        calendarAPIHost: String,
        csAPI: String,
        deviceId: String,
        acceptLanguage: @escaping @Sendable () -> String
    ) {
        self.calendarAPIHost = calendarAPIHost
        self.csAPI = csAPI
        self.deviceId = deviceId
        self.acceptLanguage = acceptLanguage
    }
    
    public func path(_ endpoint: any Endpoint) -> String {
        let prefix: String
        switch endpoint.host {
        case .calendarAPI(let path): prefix = "\(self.calendarAPIHost)/\(path)"
        case .customerService: prefix = self.csAPI
        case .external(let base): prefix = base
        }
        return endpoint.subPath.isEmpty ? prefix : "\(prefix)/\(endpoint.subPath)"
    }
}
