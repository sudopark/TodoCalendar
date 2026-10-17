//
//  EventCellViewModelMapper.swift
//  CalendarPresentation
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct EventCellViewModelMapper {

    public let range: Range<TimeInterval>
    public let timeZone: TimeZone
    public let is24hourForm: Bool

    public init(range: Range<TimeInterval>, timeZone: TimeZone, is24hourForm: Bool) {
        self.range = range
        self.timeZone = timeZone
        self.is24hourForm = is24hourForm
    }

    public func cellViewModel(from event: any CalendarEvent) -> (any EventCellViewModel)? {
        switch event {
        case let todo as TodoCalendarEvent:
            return TodoEventCellViewModel(todo, in: self.range, self.timeZone, self.is24hourForm)

        case let schedule as ScheduleCalendarEvent:
            return ScheduleEventCellViewModel(schedule, in: self.range, timeZone: self.timeZone, self.is24hourForm)

        case let holiday as HolidayCalendarEvent:
            return HolidayEventCellViewModel(holiday)

        case let google as GoogleCalendarEvent:
            return GoogleCalendarEventCellViewModel(google, in: self.range, self.timeZone, self.is24hourForm)

        case let apple as AppleCalendarEvent:
            return AppleCalendarEventCellViewModel(apple, in: self.range, self.timeZone, self.is24hourForm)

        default: return nil
        }
    }

    public func cellViewModels(from events: [any CalendarEvent]) -> [any EventCellViewModel] {
        return events.compactMap(self.cellViewModel(from:))
    }
}
