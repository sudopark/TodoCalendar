//
//  ExternalService.swift
//  Domain
//
//  Created by sudo.park on 1/26/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation

// MARK: - ExternalCalendarService

public protocol ExternalCalendarService: Sendable {

    var identifier: String { get }
    var isSingleAccountService: Bool { get }
}


// MARK: - usecase provider

public protocol ExternalCalendarOAuthUsecaseProvider: Sendable {

    func usecase(for service: any ExternalCalendarService) -> (any OAuth2ServiceUsecase)?
}


// MARK: - AppleCalendarService

public struct AppleCalendarService: ExternalCalendarService {

    public let identifier: String = AppleCalendarService.id
    public let isSingleAccountService: Bool = true

    public static var id: String { "apple" }
    /// Apple Calendar은 OAuth 계정이 없으므로 기기 로컬 계정을 나타내는 고정 ID
    public static var localAccountId: String { "device" }

    public init() {}
}


// MARK: - GoogleCalendarService

public struct GoogleCalendarService: ExternalCalendarService {
    
    public enum Scope: String, Sendable {
        case readonly = "https://www.googleapis.com/auth/calendar.readonly"
        case readWrite = "https://www.googleapis.com/auth/calendar"
    }
    
    public let identifier: String = GoogleCalendarService.id
    public let isSingleAccountService: Bool = false
    public let scopes: [Scope]
    
    public static var id: String {
        return "google"
    }
    
    public init(scopes: [Scope]) {
        self.scopes = scopes
    }
}
