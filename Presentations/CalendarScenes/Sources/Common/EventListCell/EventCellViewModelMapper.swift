//
//  EventCellViewModelMapper.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


struct EventCellViewModelMapper {

    let range: Range<TimeInterval>
    let timeZone: TimeZone
    let is24hourForm: Bool

    func cellViewModel(from event: any CalendarEvent) -> (any EventCellViewModel)? {
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

    func cellViewModels(from events: [any CalendarEvent]) -> [any EventCellViewModel] {
        return events.compactMap(self.cellViewModel(from:))
    }
}
