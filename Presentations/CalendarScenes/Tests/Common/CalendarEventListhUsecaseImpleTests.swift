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
        let currentTodos = (0..<3).map { int in
            return TodoEvent(uuid: "c-t:\(int)", name: "curent")
                |> \.eventTagId .~ .default
        }
        let todoUsecase = StubTodoEventUsecase()
        todoUsecase.stubTodoEventsInRange = todos
        todoUsecase.stubCurrentTodoEvents = currentTodos
        
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

extension CalendarEventListhUsecaseImpleTests {
    
    @Test func usecase_provideCurrentTodoList() async throws {
        // given
        let expect = expectConfirm("current todo 정보 제공")
        let usecase = self.makeUsecase()
        
        // when
        let todos = try await self.firstOutput(expect, for: usecase.currentTodoEvents())
        
        // then
        let ids = todos?.map { $0.eventId }
        #expect(ids == (0..<3).map { "c-t:\($0)" })
    }
    
    @Test func uscase_provideCurrentTodoListWithIsForemost() async throws {
        // given
        let expect = expectConfirm("current todo 제공시에 foremost 이벤트 여부 같이 제공")
        expect.count = 4
        let usecase = self.makeUsecase()
        
        // when
        let todoLists = try await self.outputs(expect, for: usecase.currentTodoEvents()) {
            
            Task {
                try await self.foremostUsecase.update(foremost: .init("c-t:1", true))
                
                try await self.foremostUsecase.update(foremost: .init("c-t:0", false))
                
                try await self.foremostUsecase.remove()
            }
        }
        
        // then
        let currentTodoIds = todoLists
                .map { ts in ts.filter { $0.isForemost } }
                .map { ts in ts.map { $0.eventId } }
        #expect(currentTodoIds == [
            [],
            ["c-t:1"],
            ["c-t:0"],
            []
        ])
    }
    
    @Test func usecase_provideCurrentTodo_withoutTagOff() async throws {
        // given
        let expect = expectConfirm("current todo 제공시 off id에 따라 필터링")
        expect.count = 3
        let usecase = self.makeUsecase()
        
        // when
        let todoLists = try await self.outputs(expect, for: usecase.currentTodoEvents()) {
            
            self.eventTagUsecase.toggleEventTagIsOnCalendar(.default)
            self.eventTagUsecase.toggleEventTagIsOnCalendar(.default)
        }
        
        // then
        let allCurrentTodoIds = (0..<3).map { "c-t:\($0)" }
        let idLists = todoLists.map { ts in ts.map { $0.eventId } }
        #expect(idLists == [
            allCurrentTodoIds,
            [],
            allCurrentTodoIds
        ])
    }
}
