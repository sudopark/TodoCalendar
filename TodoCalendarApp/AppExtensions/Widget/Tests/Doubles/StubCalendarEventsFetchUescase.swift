//
//  StubCalendarEventsFetchUescase.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 6/2/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import CalendarScenes


class StubCalendarEventsFetchUescase: CalendarEventFetchUsecase {
    
    var hasCurrentTodo: Bool = true
    var hasEventAtStartDate: Bool = true
    var hasHoliday: Bool = true
    var withoutAnyEvents: Bool = false
    
    func fetchEvents(
        in range: Range<TimeInterval>, _ timeZone: TimeZone
    ) async throws -> CalendarEvents {
        
        var sender: CalendarEvents = .init()
        
        if !withoutAnyEvents && hasCurrentTodo {
            let currentTodo = TodoEvent(uuid: "current", name: "current")
            let currentTodoEvent = TodoCalendarEvent(currentTodo, in: timeZone)
            sender.currentTodos = [currentTodoEvent]
        }
        
        if !withoutAnyEvents && hasEventAtStartDate {
            let todoAtStartDate = TodoEvent(uuid: "todo1", name: "todo_at_start")
                |> \.time .~ .at(range.lowerBound)
            let event = TodoCalendarEvent(todoAtStartDate, in: timeZone)
            sender.eventWithTimes.append(event)
        }
        
        if self.hasHoliday {
            let endDateString = Date(timeIntervalSince1970: range.upperBound-1).text("yyyy-MM-dd", timeZone: timeZone)
            let holiday = Holiday(dateString: endDateString, name: "holiday")
            if let holidayEvent = HolidayCalendarEvent(holiday, in: timeZone) {
                sender.eventWithTimes.append(holidayEvent)
            }
        }
        
        if !withoutAnyEvents {
            let scheduleAtLastDate = ScheduleEvent(
                uuid: "schedule", name: "scheudle_at_last", time: .at(range.upperBound-10)
            )
            |> \.eventTagId .~ .custom("t1")
            let scheduleAtLastEvent = ScheduleCalendarEvent.events(from: scheduleAtLastDate, in: timeZone)
            sender.eventWithTimes.append(contentsOf: scheduleAtLastEvent)
            
            let todoAtLastDate = TodoEvent(uuid: "todo2", name: "todo_at_last")
                |> \.time .~ .at(range.upperBound-1)
                |> \.eventTagId .~ .custom("t2")
            let todoAtLastEvent = TodoCalendarEvent(todoAtLastDate, in: timeZone)
            sender.eventWithTimes.append(todoAtLastEvent)
        }
        
        sender.customTagMap = [
            "t1": .init(uuid: "t1", name: "t1", colorHex: "t1"),
            "t2": .init(uuid: "t2", name: "t2", colorHex: "t2")
        ]
        
        return sender
    }
    
    var stubForemost: (any ForemostMarkableEvent)?
    func fetchForemostEvent() async throws -> ForemostEvent {
        return .init(foremostEvent: self.stubForemost, tag: nil)
    }
    
    var stubNextEvent: TodayNextEvent?
    func fetchNextEvent(
        _ refTime: Date, within todayRange: Range<TimeInterval>, _ timeZone: TimeZone
    ) async throws -> TodayNextEvent? {
        return self.stubNextEvent
    }
    
    var stubNextEvents: TodayNextEvents?
    func fetchNextEvents(
        _ refTime: Date, withIn todayRange: Range<TimeInterval>, _ timeZone: TimeZone
    ) async throws -> TodayNextEvents {
        return try self.stubNextEvents.unwrap()
    }
}
