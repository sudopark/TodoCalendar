//
//  GoogleCalendarEventColorResolver.swift
//  Domain
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - GoogleCalendar.EventColorResolver

extension GoogleCalendar {

    public struct EventColorResolver: Sendable {

        private let calendarTags: [String: Tag]
        private let palettes: [String: Colors]

        public init(calendarTags: [String: Tag], palettes: [String: Colors]) {
            self.calendarTags = calendarTags
            self.palettes = palettes
        }

        public func colorHex(eventColorId: String?, calendarId: String) -> String? {
            let tag = self.calendarTags[calendarId]
            let accountId = tag?.ownerId
            guard let eventColorId else {
                return self.calendarColorHex(tag: tag, accountId: accountId)
            }
            return self.eventColorHex(eventColorId, accountId: accountId)
        }
    }
}


extension GoogleCalendar.EventColorResolver {

    private func eventColorHex(_ colorId: String, accountId: String?) -> String? {
        guard let accountId else {
            return self.palettes.values.lazy.compactMap { $0.events[colorId] }.first?.backgroudHex
        }
        return self.palettes[accountId]?.events[colorId]?.backgroudHex
    }

    private func calendarColorHex(tag: GoogleCalendar.Tag?, accountId: String?) -> String? {
        if let backgroundColorHex = tag?.backgroundColorHex {
            return backgroundColorHex
        }
        guard let paletteId = tag?.colorId else { return nil }
        guard let accountId else {
            return self.palettes.values.lazy.compactMap { $0.calendars[paletteId] }.first?.backgroudHex
        }
        return self.palettes[accountId]?.calendars[paletteId]?.backgroudHex
    }
}
