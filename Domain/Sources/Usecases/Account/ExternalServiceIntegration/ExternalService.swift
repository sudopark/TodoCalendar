//
//  ExternalService.swift
//  Domain
//
//  Created by sudo.park on 1/26/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import UIKit

// MARK: - ExternalCalendarService

public protocol ExternalCalendarService: Sendable {
    
    var identifier: String { get }
}


// MARK: - usecase provider

public protocol ExternalCalendarOAuthUsecaseProvider: Sendable {
    
    func usecase(for service: any ExternalCalendarService) -> (any OAuth2ServiceUsecase)?
}

public final class ExternalCalendarOAuthUsecaseProviderImple: ExternalCalendarOAuthUsecaseProvider, @unchecked Sendable {
    
    private let topViewControllerFinding: () -> UIViewController?
    public init(topViewControllerFinding: @escaping () -> UIViewController?) {
        self.topViewControllerFinding = topViewControllerFinding
    }
    
    public func usecase(for service: any ExternalCalendarService) -> (any OAuth2ServiceUsecase)? {
        
        switch service {
        case let google as GoogleCalendarService:
            return GoogleOAuth2ServiceUsecaseImple(
                additionalScope: google.scopes.map { $0.rawValue },
                topViewControllerFinding: self.topViewControllerFinding
            )
            
        default:
            return nil
        }
    }
}


// MARK: - GoogleCalendarService

public struct GoogleCalendarService: ExternalCalendarService {
    
    public enum Scope: String, Sendable {
        case readOnly = "https://www.googleapis.com/auth/calendar.readonly"
    }
    
    public let identifier: String = GoogleCalendarService.id
    public let scopes: [Scope]
    
    public static var id: String {
        return "google"
    }
    
    public init(scopes: [Scope]) {
        self.scopes = scopes
    }
}
