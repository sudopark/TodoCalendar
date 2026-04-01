//
//  StubAppleCalendarUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 3/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


open class StubAppleCalendarUsecase: AppleCalendarUsecase, @unchecked Sendable {

    public init() { }

    public var didPrepared = false
    open func prepare() {
        didPrepared = true
    }

    open func refreshCalendarTags() {
        let tags = self.stubCalendarTags ?? (0..<5).map { int -> AppleCalendar.Tag in
            return .init(id: "a:\(int)", name: "a:\(int)", colorHex: "hex")
        }
        self.tagsSubject.send(tags)
    }

    open func refreshEvents(in period: Range<TimeInterval>) { }

    private let tagsSubject = CurrentValueSubject<[AppleCalendar.Tag]?, Never>(nil)
    public var stubCalendarTags: [AppleCalendar.Tag]?
    open var calendarTags: AnyPublisher<[AppleCalendar.Tag], Never> {
        tagsSubject.compactMap { $0 }.eraseToAnyPublisher()
    }

    public func sendCalendarTags(_ tags: [AppleCalendar.Tag]) {
        tagsSubject.send(tags)
    }

    public var stubEvents: [AppleCalendar.Event] = []
    open func events(in period: Range<TimeInterval>) -> AnyPublisher<[AppleCalendar.Event], Never> {
        Just(stubEvents).eraseToAnyPublisher()
    }
}
