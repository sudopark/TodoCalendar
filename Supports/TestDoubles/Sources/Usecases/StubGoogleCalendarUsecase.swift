//
//  StubGoogleCalendarUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2/15/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions


open class StubGoogleCalendarUsecase: GoogleCalendarUsecase, @unchecked Sendable {

    public init() { }

    public var googleService: GoogleCalendarService = .init(scopes: [.readWrite])

    public var didPrepared = false
    open func prepare() {
        self.didPrepared = true
    }
    
    private let tagsSubject = CurrentValueSubject<[GoogleCalendar.Tag]?, Never>(nil)
    public var stubCalendarTags: [GoogleCalendar.Tag]?
    open func refreshGoogleCalendarEventTags() {
        let tags = self.stubCalendarTags ?? (0..<10).map { int -> GoogleCalendar.Tag in
            return .init(id: "g:\(int)", name: "g:\(int)")
                |> \.colorId .~ "color"
                |> \.backgroundColorHex .~ "hex"
                |> \.ownerId .~ "user@gmail.com"
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

    public var didRefreshRepeatingEventWith: (calendarId: String, eventId: String, accountId: String, period: Range<TimeInterval>)?
    open func refreshRepeatingEvent(
        _ calendarId: String,
        _ eventId: String,
        accountId: String,
        in period: Range<TimeInterval>
    ) {
        self.didRefreshRepeatingEventWith = (calendarId, eventId, accountId, period)
    }
    
    public var stubEvents: [GoogleCalendar.Event] = []
    open func events(in period: Range<TimeInterval>) -> AnyPublisher<[GoogleCalendar.Event], Never> {
        return Just(self.stubEvents).eraseToAnyPublisher()
    }
    
    public var stubDetail: GoogleCalendar.EventOrigin?
    open func eventDetail(
        _ calendarId: String, _ eventId: String, accountId: String, at timeZone: TimeZone
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        guard let detail = self.stubDetail
        else {
            return Empty().eraseToAnyPublisher()
        }
        return Just(detail).mapAsAnyError().eraseToAnyPublisher()
    }
    
    private let accountSubject = CurrentValueSubject<ExternalServiceAccountinfo?, Never>(nil)
    public func updateHasAccount(_ account: ExternalServiceAccountinfo?) {
        self.accountSubject.send(account)
    }
    open var integratedAccount: AnyPublisher<ExternalServiceAccountinfo?, Never> {
        return self.accountSubject
            .eraseToAnyPublisher()
    }

    public var stubWritePermission: GoogleCalendar.EventWritePermission = .writable
    open func eventWritePermission(
        accountId: String, calendarId: String
    ) -> AnyPublisher<GoogleCalendar.EventWritePermission, Never> {
        return Just(self.stubWritePermission).eraseToAnyPublisher()
    }

    public var didUpdateEventWith: (calendarId: String, eventId: String, accountId: String, params: GoogleCalendar.EventEditParams)?
    public var stubUpdatedEventOrigin: GoogleCalendar.EventOrigin?
    open func updateEvent(
        _ calendarId: String,
        _ eventId: String,
        accountId: String,
        at timeZone: TimeZone,
        params: GoogleCalendar.EventEditParams
    ) async throws -> GoogleCalendar.EventOrigin {
        self.didUpdateEventWith = (calendarId, eventId, accountId, params)
        guard let origin = self.stubUpdatedEventOrigin
        else {
            throw RuntimeError("stubUpdatedEventOrigin not set")
        }
        return origin
    }

    public var didRemoveEventWith: (calendarId: String, eventId: String, accountId: String)?
    open func removeEvent(
        _ calendarId: String,
        _ eventId: String,
        accountId: String
    ) async throws {
        self.didRemoveEventWith = (calendarId, eventId, accountId)
    }
}
