//
//  EventCountdownActivityViewModel.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SwiftUI
import CommonPresentation


struct EventCountdownActivityViewModel {

    let eventName: String
    let eventTimeText: String
    let eventDate: Date
    let startDate: Date
    let subtitle: String?
    let tagColor: Color
    let todoId: String?
    let deepLink: URL?

    init(_ attributes: EventCountdownActivityAttributes, _ state: EventCountdownActivityAttributes.State) {
        self.eventName = state.eventName
        self.eventTimeText = state.eventTimeText
        self.eventDate = state.eventDate
        self.startDate = state.startDate
        self.subtitle = state.placeName?.nonEmptyTrimmed ?? state.memo?.nonEmptyTrimmed

        switch attributes.target {
        case .todo(let id):
            self.todoId = id
        case .schedule, .holiday, .googleCalendar, .appleCalendar:
            self.todoId = nil
        }

        self.deepLink = attributes.target.eventDetailURL(scheduleTimeQuery: state.scheduleTimeQuery)

        let uiColor = UIColor.from(hex: state.tagColorHex) ?? .gray
        self.tagColor = uiColor.asColor
    }
}


private extension String {

    var nonEmptyTrimmed: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
