//
//  AppColdLaunchHistory.swift
//  Domain
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct AppColdLaunchHistory: Equatable, Sendable {

    public var firstLaunchDate: Date?
    public var count: Int
    public var previousLaunchDate: Date?
    public var lastLaunchDate: Date?

    public init() {
        self.firstLaunchDate = nil
        self.count = 0
        self.previousLaunchDate = nil
        self.lastLaunchDate = nil
    }
}

extension AppColdLaunchHistory {

    public mutating func recordLaunch(at now: Date) {
        if self.firstLaunchDate == nil {
            self.firstLaunchDate = now
        }
        self.previousLaunchDate = self.lastLaunchDate
        self.lastLaunchDate = now
        self.count += 1
    }

    public func isFirstLaunchOfDay(_ calendar: Calendar) -> Bool {
        guard let previousLaunchDate = self.previousLaunchDate,
              let lastLaunchDate = self.lastLaunchDate
        else { return true }
        return calendar.isDate(previousLaunchDate, inSameDayAs: lastLaunchDate) == false
    }

    public func elapsedDaysFromFirstLaunch(to now: Date, _ calendar: Calendar) -> Int {
        guard let firstLaunchDate = self.firstLaunchDate else { return 0 }
        let from = calendar.startOfDay(for: firstLaunchDate)
        let to = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}
