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
    
    private let tagsSubject = CurrentValueSubject<[GoogleCalendar.Tag]?, Never>(nil)
    open func refreshGoogleCalendarEventTags() {
        let tags = (0..<10).map { int -> GoogleCalendar.Tag in
            return .init(id: "g:\(int)", name: "g:\(int)")
        }
        self.tagsSubject.send(tags)
    }
    
    open var calendarTags: AnyPublisher<[GoogleCalendar.Tag], Never> {
        return self.tagsSubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    open func refreshEvents(in period: Range<TimeInterval>) {
        
    }
    
    public var stubEvents: [GoogleCalendar.Event] = []
    open func events(in period: Range<TimeInterval>) -> AnyPublisher<[GoogleCalendar.Event], Never> {
        return Just(self.stubEvents).eraseToAnyPublisher()
    }
    
    open func eventDetail(
        _ calendarId: String, _ eventId: String, at timeZone: TimeZone
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        return Empty().eraseToAnyPublisher()
    }
    
    private let accountSubject = CurrentValueSubject<ExternalServiceAccountinfo?, Never>(nil)
    public func updateHasAccount(_ account: ExternalServiceAccountinfo?) {
        self.accountSubject.send(account)
    }
    open var integratedAccount: AnyPublisher<ExternalServiceAccountinfo?, Never> {
        return self.accountSubject
            .eraseToAnyPublisher()
    }
}
