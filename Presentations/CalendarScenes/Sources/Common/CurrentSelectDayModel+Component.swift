//
//  CurrentSelectDayModel+Component.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions


extension CurrentSelectDayModel {
    
    init?(
        day: CalendarDay,
        _ component: CalendarComponent,
        _ timeZone: TimeZone
    ) {
        self.init(
            day.year, day.month, day.day, component, timeZone
        )
        self.holidays = component.holiday(day.month, day.day) ?? []
    }
    
    init?(
        today: CalendarComponent.Day,
        _ component: CalendarComponent,
        _ timeZone: TimeZone
    ) {
        self.init(today.year, today.month, today.day, component, timeZone)
        self.holidays = component.holiday(today.month, today.day) ?? []
    }
    
    init?(
        firstDayOf month: CalendarComponent,
        _ timeZone: TimeZone
    ) {
        guard let firstDay = month.weeks.flatMap({ $0.days }).first(where: { $0.month == month.month && $0.day == 1 })
        else { return nil }
        self.init(firstDay.year, firstDay.month, firstDay.day, month, timeZone)
        self.holidays = month.holiday(firstDay.month, firstDay.day) ?? []
    }
    
    private init?(
        _ year: Int, _ month: Int, _ day: Int,
        _ component: CalendarComponent, _ timeZone: TimeZone
    ) {
        let identifier = "\(year)-\(month)-\(day)"
        let findWeekContainsDay: (CalendarComponent.Week) -> Bool = { week in
            return week.days.first(where: { $0.identifier == identifier }) != nil
        }
        guard let week = component.weeks.first(where: findWeekContainsDay)
        else { return nil }
        
        let component = DateComponents(year: year, month: month, day: day)
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        guard let date = calendar.date(from: component),
              let range = calendar.dayRange(date)
        else { return nil }
        self.init(year, month, day, weekId: week.id, range: range)
    }
}
