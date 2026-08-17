//
//  SharePreviewLineModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


struct SharePreviewLineModel: Equatable, Sendable, Identifiable {
    let eventId: String
    /// nil = 날짜에 매이지 않는 할일 (시간 없는 current todo)
    let dayStart: TimeInterval?
    let name: String
    var timeText: String?
    var tagId: EventTagId?
    var tagName: String?
    var isExcluded: Bool = false
    var isExcludedByTag: Bool = false
    var isTodo: Bool = false

    var id: String { self.eventId }

    init(
        eventId: String,
        dayStart: TimeInterval?,
        name: String,
        timeText: String? = nil,
        tagId: EventTagId? = nil,
        tagName: String? = nil,
        isExcluded: Bool = false,
        isExcludedByTag: Bool = false,
        isTodo: Bool = false
    ) {
        self.eventId = eventId
        self.dayStart = dayStart
        self.name = name
        self.timeText = timeText
        self.tagId = tagId
        self.tagName = tagName
        self.isExcluded = isExcluded
        self.isExcludedByTag = isExcludedByTag
        self.isTodo = isTodo
    }

    init(
        _ calendarEvent: any CalendarEvent,
        range: Range<TimeInterval>,
        timeZone: TimeZone,
        isShort: Bool
    ) {
        let dayStart = SharePreviewLineModelFactory.dayStart(for: calendarEvent, in: range, timeZone: timeZone)
        let dayRange = SharePreviewLineModelFactory.dayRange(
            startingAt: dayStart ?? range.lowerBound, timeZone: timeZone
        )
        let timeText = SharePreviewLineModelFactory.timeText(
            eventTime: calendarEvent.eventTime, dayRange: dayRange, timeZone: timeZone, isShort: isShort
        )
        self.init(
            eventId: calendarEvent.eventId,
            dayStart: dayStart,
            name: calendarEvent.name,
            timeText: timeText,
            tagId: calendarEvent.eventTagId,
            isTodo: calendarEvent is TodoCalendarEvent
        )
    }
}


// MARK: - SharePreviewLineModelFactory

private enum SharePreviewLineModelFactory {

    static func dayStart(
        for calendarEvent: any CalendarEvent, in range: Range<TimeInterval>, timeZone: TimeZone
    ) -> TimeInterval? {
        guard let anchor = calendarEvent.eventTimeOnCalendar?.clamped(to: range)?.lowerBound
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: Date(timeIntervalSince1970: anchor)).timeIntervalSince1970
    }

    static func dayRange(startingAt dayStart: TimeInterval, timeZone: TimeZone) -> Range<TimeInterval> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = Date(timeIntervalSince1970: dayStart)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        return dayStart..<end.timeIntervalSince1970
    }

    static func timeText(
        eventTime: EventTime?, dayRange: Range<TimeInterval>, timeZone: TimeZone, isShort: Bool
    ) -> String? {
        guard let eventTime else { return nil }

        if case .at(let time) = eventTime {
            return EventTimeText(time: time, timeZone, isShort).singleLineText
        }

        let (isAllTodayTimeContains, starttimeInToday, endTimeInToday) = dayRange.checkTodayRangeBound(eventTime, timeZone: timeZone)
        if isAllTodayTimeContains {
            return R.String.calendarEventTimeAllday
        }

        switch (starttimeInToday, endTimeInToday) {
        case (true, true):
            let start = EventTimeText(time: eventTime.lowerBoundWithFixed, timeZone, isShort).singleLineText
            let end = EventTimeText(time: eventTime.upperBoundWithFixed, timeZone, isShort).singleLineText
            return "\(start)~\(end)"

        case (true, false):
            let start = EventTimeText(time: eventTime.lowerBoundWithFixed, timeZone, isShort).singleLineText
            return "\(start)~"

        case (false, true):
            let end = EventTimeText(time: eventTime.upperBoundWithFixed, timeZone, isShort).singleLineText
            return "~\(end)"

        case (false, false):
            return nil
        }
    }
}
