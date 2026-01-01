//
//  EventCellViewModel+WdigetURL+Tests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 1/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Domain
import Scenes
import CalendarScenes
import TestDoubles

struct EventCellViewModelWidgetURL_Tests {
    
    func makeTodoModel() -> TodoEventCellViewModel {
        let todo = TodoEvent.dummy(0)
        let event = TodoCalendarEvent(todo, in: .current)
        return .init(currentTodo: event)
    }
    
    func makeScheduleModel() -> ScheduleEventCellViewModel {
        let schedule = ScheduleEvent(uuid: "sc", name: "some", time: .at(100))
        let event = ScheduleCalendarEvent.events(from: schedule, in: .current).first!
        return .init(event, in: 0..<10, timeZone: .current, true)!
    }
    
    func makeHolidayModel() -> HolidayEventCellViewModel {
        let holiday = Holiday(uuid: "holiday!@#$%^한글", dateString: "2023-02-01", name: "some")
        let event = HolidayCalendarEvent(holiday, in: .current)!
        return .init(event)
    }
    
    func makeGoogleModel() -> GoogleCalendarEventCellViewModel {
        let google = GoogleCalendar.Event("event", "calendar", name: "some", colorId: nil, time: .at(100))
        let event = GoogleCalendarEvent(google, in: .current)
        return .init(event, in: 0..<10, .current, true)!
    }
}

extension EventCellViewModelWidgetURL_Tests {
    
    @Test func todoCellViewModel_widgetURL() {
        // given
        let todo = self.makeTodoModel()
        
        // when
        let url = todo.widgetURL
        
        // then
        let link = url.flatMap { PendingDeepLink($0) }
        #expect(link?.scheme == "tc.app")
        #expect(link?.host == "calendar")
        #expect(link?.pendingPathComponents == ["event", "todo"])
        #expect(link?.queryParams.count == 1)
        #expect(link?.queryParams["event_id"] == "id:0")
    }
    
    @Test func scheduleCellViewModel_widgetURL() {
        // given
        let schedule = self.makeScheduleModel()
        
        // when
        let url = schedule.widgetURL
        
        // then
        let link = url.flatMap { PendingDeepLink($0) }
        #expect(link?.scheme == "tc.app")
        #expect(link?.host == "calendar")
        #expect(link?.pendingPathComponents == ["event", "schedule"])
        #expect(link?.queryParams.count == 2)
        #expect(link?.queryParams["event_id"] == "sc")
        #expect(link?.queryParams["at"] == "100.0")
    }
    
    @Test func holidayCellViewModel_widgetURL() {
        // given
        let holiday = self.makeHolidayModel()
        
        // when
        let url = holiday.widgetURL
        
        // then
        let link = url.flatMap { PendingDeepLink($0) }
        #expect(link?.scheme == "tc.app")
        #expect(link?.host == "calendar")
        #expect(link?.pendingPathComponents == ["event", "holiday"])
        #expect(link?.queryParams.count == 1)
        #expect(link?.queryParams["event_id"] == "holiday!@#$%^한글")
    }
    
    @Test func googleCellViewModel_widgetURL() {
        // given
        let google = self.makeGoogleModel()
        
        // when
        let url = google.widgetURL
        
        // then
        let link = url.flatMap { PendingDeepLink($0) }
        #expect(link?.scheme == "tc.app")
        #expect(link?.host == "calendar")
        #expect(link?.pendingPathComponents == ["event", "google"])
        #expect(link?.queryParams.count == 2)
        #expect(link?.queryParams["event_id"] == "event")
        #expect(link?.queryParams["calendar_id"] == "calendar")
    }
}
