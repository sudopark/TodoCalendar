//
//  EventDeepLinkHandlerImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 12/28/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics
import Domain
import Scenes

@testable import CalendarScenes


class EventDeepLinkHandlerImpleTests {
    
    private let spyRouter = SpyEventListCellEventHanleRouter()
    
    private func makeHandler(
        withPrepared: Bool = true
    ) -> EventDeepLinkHandlerImple {
        let handler = EventDeepLinkHandlerImple()
        if withPrepared {
            handler.attach(router: self.spyRouter)
        }
        return handler
    }
    
    private func makeLink(
        _ path: String, _ queries: [String: String]
    ) -> PendingDeepLink {
        let url = URL(string: "tc.app://calendar/event")!
            .appending(path: path)
            .appending(queryItems: queries.map { .init(name: $0.key, value: $0.value) })
        var link = PendingDeepLink(url)!
        _ = link.removeFirstPath()
        return link
    }
}

extension EventDeepLinkHandlerImpleTests {
    
    // handle todo detail link
    @Test func handler_handleTodoLink() {
        // given
        let handler = self.makeHandler()
        let link = self.makeLink("todo", ["event_id": "todo_id"])
        
        // when
        let result = handler.handleLink(link)
        
        // then
        #expect(result == .handle)
        #expect(self.spyRouter.didDismissPresented == true)
        #expect(self.spyRouter.didRouteToTodoDetail == true)
    }
    
    // handle schedule link
    @Test("handle schedule link", arguments: [
        EventTime.at(100.2),
        .period(100.2..<123.33),
        .allDay(22.33..<123.33, secondsFromGMT: 100)
    ])
    func handler_handleSchedule(_ time: EventTime) {
        // given
        let handler = self.makeHandler()
        let params = time.queryParams |> key("event_id") .~ "schedule_id"
        let link = self.makeLink("schedule", params)
        
        // when
        let result = handler.handleLink(link)
        
        // then
        #expect(result == .handle)
        #expect(self.spyRouter.didDismissPresented == true)
        #expect(self.spyRouter.didRouteToScheduleDetail == true)
        #expect(self.spyRouter.didRouteToScheduleDetailWithTargetTime == time)
    }
    
    // handle holiday link
    @Test func handler_handleHolidayLink() {
        // given
        let handler = self.makeHandler()
        let link = self.makeLink("holiday", ["event_id": "holiday_id"])
        
        // when
        let result = handler.handleLink(link)
        
        // then
        #expect(result == .handle)
        #expect(self.spyRouter.didDismissPresented == true)
        #expect(self.spyRouter.didRouteToHolidayEventDetailWithId == "holiday_id")
    }
    
    // handle google link
    @Test func handler_handleGoogleCalendarEventLink() {
        // given
        let handler = self.makeHandler()
        let link = self.makeLink("google", [
            "event_id": "event_id",
            "calendar_id": "calendar_id"
        ])
        
        // when
        let result = handler.handleLink(link)
        
        // then
        #expect(result == .handle)
        #expect(self.spyRouter.didDismissPresented == true)
        #expect(self.spyRouter.didRouteToGoogleEventDetailWithId == "event_id")
    }
    
    // handle link after ready
    @Test func handler_handleLink_afterIsReady() {
        // given
        let handler = self.makeHandler(withPrepared: false)
        let link = self.makeLink("todo", ["event_id": "id"])
        
        // when + then
        let resultBeforeReady = handler.handleLink(link)
        #expect(resultBeforeReady == .handle)
        #expect(self.spyRouter.didDismissPresented == nil)
        #expect(self.spyRouter.didRouteToTodoDetail == nil)
        
        handler.attach(router: self.spyRouter)
        #expect(self.spyRouter.didDismissPresented == true)
        #expect(self.spyRouter.didRouteToTodoDetail == true)
    }
}
