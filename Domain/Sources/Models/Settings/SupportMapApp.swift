//
//  SupportMapApp.swift
//  Domain
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation


public enum SupportMapApps: String, Sendable {
    
    case apple
    case google
    
    public var iconName: String {
        switch self {
        case .apple: return "apple_map"
        case .google: return "google_map"
        }
    }
    
    public var name: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        }
    }
    
    public func appURL(with query: String) -> URL? {
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        
        let urlString = switch self {
            case .apple: "maps://?q=\(encodedQuery)"
            case .google: "comgooglemaps://?q=\(encodedQuery)"
        }
        return URL(string: urlString)
    }
}
