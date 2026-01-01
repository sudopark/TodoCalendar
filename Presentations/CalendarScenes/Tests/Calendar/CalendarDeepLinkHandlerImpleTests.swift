//
//  CalendarDeepLinkHandlerImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 1/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Domain
import Scenes

@testable import CalendarScenes


struct CalendarDeepLinkHandlerImpleTests {
    
    private let spyCalendarInteractor = SpyCalendarInteractor()
    private let spyEventLinkHandler = SpyEventLinkHandler()
    
    func makeHandler(
        withCalendarInteractor: Bool = true,
        withEventHandler: Bool = true
    ) -> CalendarDeepLinkHandlerImple {
        
        let handler = CalendarDeepLinkHandlerImple()
        if withCalendarInteractor {
            handler.attach(calendarInteractor: self.spyCalendarInteractor)
        }
        if withEventHandler {
            handler.attach(eventHandler: self.spyEventLinkHandler)
        }
        return handler
    }
    
    private var eventLink: PendingDeepLink {
        return PendingDeepLink(URL(string: "tc.app://calendar/event/pending")!)!
    }
    
    private var moveMonthLink: PendingDeepLink {
        let path = "tc.app://calendar?select=2020_03"
        return PendingDeepLink(URL(string: path)!)!
    }
    
    private var moveDateLink: PendingDeepLink {
        let path = "tc.app://calendar?select=2020_03_12"
        return PendingDeepLink(URL(string: path)!)!
    }
}

extension CalendarDeepLinkHandlerImpleTests {
    
    // handle event link
    @Test func handler_handleEventLink() {
        // given
        let handler = self.makeHandler()
        
        // when
        let result = handler.handleLink(self.eventLink)
        
        // then
        #expect(result == .handle)
        #expect(self.spyEventLinkHandler.didHandleLink?.pendingPathComponents == ["pending"])
    }
    
    // hanle move date link
    @Test func handler_handleSelectMonthOrDateLink() {
        // given
        let handler = self.makeHandler()
        
        // when + then
        _ = handler.handleLink(self.moveMonthLink)
        #expect(self.spyCalendarInteractor.didMoveToDayWithClearPresented == true)
        #expect(self.spyCalendarInteractor.didMoveToDay == .init(2020, 3, 1))
        
        _ = handler.handleLink(self.moveDateLink)
        #expect(self.spyCalendarInteractor.didMoveToDay == .init(2020, 3, 12))
    }
    
    // handle pending evnet link
    @Test func handler_handleEventLink_afterAttachEventHandler() {
        // given
        let handler = self.makeHandler(withEventHandler: false)
        
        // when
        _ = handler.handleLink(self.eventLink)
        #expect(self.spyEventLinkHandler.didHandleLink == nil)
        handler.attach(eventHandler: self.spyEventLinkHandler)
        
        // then
        #expect(self.spyEventLinkHandler.didHandleLink?.pendingPathComponents == ["pending"])
    }
    
    // handle pending move date link
    @Test func handler_handleSelectDateLink_afterAttachInteractor() {
        // given
        let handler = self.makeHandler(withCalendarInteractor: false)
        
        // when
        _ = handler.handleLink(self.moveDateLink)
        #expect(self.spyCalendarInteractor.didMoveToDay == nil)
        handler.attach(calendarInteractor: self.spyCalendarInteractor)
        
        // then
        #expect(self.spyCalendarInteractor.didMoveToDay == .init(2020, 3, 12))
    }
}

private final class SpyCalendarInteractor: CalendarSceneInteractor, @unchecked Sendable {
    
    func moveFocusToToday() { }
    
    var didMoveToDay: CalendarDay?
    var didMoveToDayWithClearPresented: Bool?
    func moveDay(_ day: CalendarDay, withClearPresented: Bool) {
        self.didMoveToDay = day
        self.didMoveToDayWithClearPresented = withClearPresented
    }
}

private final class SpyEventLinkHandler: DeepLinkHandler, @unchecked Sendable {
    
    var didHandleLink: PendingDeepLink?
    func handleLink(_ link: PendingDeepLink) -> DeepLinkHandleResult {
        
        self.didHandleLink = link
        return .handle
    }
}
