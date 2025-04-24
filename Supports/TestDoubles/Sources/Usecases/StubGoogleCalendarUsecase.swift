//
//  StubGoogleCalendarUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2/15/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


open class StubGoogleCalendarUsecase: GoogleCalendarUsecase, @unchecked Sendable {
    
    public init() { }
    
    public var didPrepared = false
    open func prepare() {
        self.didPrepared = true
    }
    
    open func refreshEvents(in period: Range<TimeInterval>) {
        
    }
    
    open func events(in period: Range<TimeInterval>) -> AnyPublisher<[GoogleCalendar.Event], Never> {
        return Empty().eraseToAnyPublisher()
    }
    
    open func eventDetail(
        _ calendarId: String, _ eventId: String, at timeZone: TimeZone
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        return Empty().eraseToAnyPublisher()
    }
    
    open var integratedAccount: AnyPublisher<ExternalServiceAccountinfo?, Never> {
        return Empty().eraseToAnyPublisher()
    }
}
