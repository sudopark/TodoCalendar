//
//  CalendarEventListhUsecaseImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 5/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import CalendarScenes


final class CalendarEventListhUsecaseImpleTests: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = []
    private let foremostUsecase = StubForemostEventUsecase()
    private let eventTagUsecase = StubEventTagUsecase()
    private let uiSettingUsecase = StubUISettingUsecase()
    
    private func makeUsecase() -> CalendarEventListhUsecaseImple {
        let todos = (0..<3).map { int in
            return TodoEvent(uuid: "todo:\(int)", name: "todo")
                |> \.time .~ .at(0)
                |> \.eventTagId .~ .default
        }
        let schedules = (0..<3).map { int in
            return ScheduleEvent(uuid: "sc:\(int)", name: "sc", time: .at(0))
                |> \.eventTagId .~ .default
        }
        let googles = (0..<3).map { int in
            return GoogleCalendar.Event("g:\(int)", "google", name: "g", time: .at(0))
                |> \.eventTagId .~ .externalCalendar(serviceId: GoogleCalendarService.id, id: "google")
        }
        let todoUsecase = StubTodoEventUsecase()
        todoUsecase.stubTodoEventsInRange = todos
        
        let scheduleUsecase = StubScheduleEventUsecase()
        scheduleUsecase.stubScheduleEventsInRange = schedules
        
        let googleUsecase = StubGoogleCalendarUsecase()
        googleUsecase.stubEvents = googles
        
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.prepare()
        
        return .init(
            todoUsecase: todoUsecase,
            scheduleUsecase: scheduleUsecase,
            googleCalendarUsecase: googleUsecase,
            foremostEventUsecase: self.foremostUsecase,
            calendarSettingUsecase: calendarSettingUsecase,
            eventTagUsecase: self.eventTagUsecase,
            uiSettingUsecase: self.uiSettingUsecase
        )
    }
}


extension CalendarEventListhUsecaseImpleTests {
    
    @Test func usecase_getCalendarEvents() async throws {
        // given
        let expect = expectConfirm("이벤트 리스트 제공, todo, schedule, google event")
        let usecase = self.makeUsecase()
        
        // when
        let eventSource = usecase.calendarEvents(in: 0..<10)
        let events = try await self.firstOutput(expect, for: eventSource)
        
        // then
        let ids = events?.map { $0.eventId }
        #expect(ids == (0..<3).map { "todo:\($0)"} + (0..<3).map { "sc:\($0)-1" } + (0..<3).map { "g:\($0)" } )
    }
    
    @Test func usecase_whenForemostEventUpdated_updateCalendarEventList() async throws {
        // given
        let expect = expectConfirm("foremost 설정 여부에 따라 리스트 업데이트")
        expect.count = 4
        expect.timeout = .milliseconds(500)
        let usecase = self.makeUsecase()
        
        // when
        let eventSource = usecase.calendarEvents(in: 0..<10)
        let eventLists = try await self.outputs(expect, for: eventSource) {
            Task {
                try await self.foremostUsecase.update(foremost: .init("todo:1", true))
                
                try await self.foremostUsecase.update(foremost: .init("sc:0", false))
                
                try await self.foremostUsecase.remove()
            }
        }
        
        // then
        let foremostEventIdsInList = eventLists.map { es in
            return es.filter { $0.isForemost }.map { $0.eventId }
        }
        #expect(foremostEventIdsInList == [
            [],
            ["todo:1"],
            ["sc:0-1"],
            []
        ])
    }
    
    @Test func usecase_whenOffTagIdUpdated_updateCalendarList() async throws {
        // given
        let expect = expectConfirm("비활성화된 태그 이벤트는 제외")
        expect.count = 4
        expect.timeout = .milliseconds(500)
        let usecase = self.makeUsecase()
        
        // when
        let eventSource = usecase.calendarEvents(in: 0..<10)
        let eventLists = try await self.outputs(expect, for: eventSource) {
            self.eventTagUsecase.toggleEventTagIsOnCalendar(.default)
            self.eventTagUsecase.toggleEventTagIsOnCalendar(
                .externalCalendar(serviceId: GoogleCalendarService.id, id: "google")
            )
            self.eventTagUsecase.toggleEventTagIsOnCalendar(.default)
        }
        
        // then
        let idLists = eventLists.map { es in es.map { $0.eventId } }
        let allIds = (0..<3).map { "todo:\($0)"} + (0..<3).map { "sc:\($0)-1" } + (0..<3).map { "g:\($0)"}
        let onlyGoogles = (0..<3).map { "g:\($0)" }
        let withoutGoogles = (0..<3).map { "todo:\($0)"} + (0..<3).map { "sc:\($0)-1" }
        #expect(idLists == [
            allIds,
            onlyGoogles,
            [],
            withoutGoogles
        ])
    }
}
