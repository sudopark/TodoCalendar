//
//  StubAppleCalendarRepository.swift
//  TestDoubles
//
//  Created by sudo.park on 3/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


open class StubAppleCalendarRepository: AppleCalendarRepository, @unchecked Sendable {

    public init() { }

    public var stubAccessStatus: Bool = true
    open func checkAccessStatus() -> Bool {
        return stubAccessStatus
    }

    public var stubRequestAccess: Bool = true
    open func requestAccess() async throws -> Bool {
        return stubRequestAccess
    }

    public var stubCalendarTags: [AppleCalendar.Tag] = (0..<3).map {
        .init(id: "cal:\($0)", name: "Calendar \($0)", colorHex: nil)
    }
    open func loadCalendarTags() async throws -> [AppleCalendar.Tag] {
        return stubCalendarTags
    }

    public var stubEvents: [AppleCalendar.Event] = []
    open func loadEvents(
        in period: Range<TimeInterval>,
        timeZone: TimeZone
    ) async throws -> [AppleCalendar.Event] {
        return stubEvents
    }

    public var didResetCache = false
    open func resetCache() async throws {
        didResetCache = true
    }
}
