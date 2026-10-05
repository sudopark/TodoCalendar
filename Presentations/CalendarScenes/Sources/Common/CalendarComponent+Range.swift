//
//  CalendarComponent+Range.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import CalendarPresentation


extension CalendarComponent {

    func intervalRange(at timeZone: TimeZone) -> Range<TimeInterval>? {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        guard let startDay = self.weeks.first?.days.first,
              let endDay = self.weeks.last?.days.last,
              let startDate = calendar.date(from: startDay).flatMap(calendar.startOfDay(for:)),
              let endDate = calendar.date(from: endDay).flatMap(calendar.endOfDay(for:))
        else { return nil }

        return startDate.timeIntervalSince1970..<endDate.timeIntervalSince1970
    }

    func holidayCalendarEvents(with timeZone: TimeZone) -> [any CalendarEvent] {
        return self.weeks
            .flatMap { $0.days }
            .flatMap { $0.holidays }
            .compactMap { HolidayCalendarEvent($0, in: timeZone) }
    }

    func shareRange(
        _ kind: CalendarShareRangeKind, for day: DayCellViewModel, timeZone: TimeZone
    ) -> Range<TimeInterval>? {
        switch kind {
        case .day:
            return CalendarComponent.Day(
                year: day.year, month: day.month, day: day.day, weekDay: 1
            ).dayRange(timeZone)

        case .week:
            return self.weeks
                .first(where: { week in week.days.contains(where: { $0.identifier == day.identifier }) })?
                .range(timeZone)

        case .month:
            return self.monthRange(timeZone)
        }
    }
}
