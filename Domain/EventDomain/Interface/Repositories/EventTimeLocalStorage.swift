//
//  EventTimeLocalStorage.swift
//  EventDomainInterface
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol EventTimeLocalStorage: Sendable {

    func loadTimes(overlapping range: Range<TimeInterval>) async throws -> [String: EventTime]
    func loadTime(eventId: String) async throws -> EventTime?
    func saveTimes(_ times: [String: EventTime]) async throws
    func removeTimes(eventIds: [String]) async throws
    func removeAllTimes() async throws
}
