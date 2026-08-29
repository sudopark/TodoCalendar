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
    
    private func makeUsecase(
        appleEvents: [AppleCalendar.Event] = [],
        offTagIds: [EventTagId] = [],
        googleEvents: [GoogleCalendar.Event]? = nil,
        googleCalendarTags: [GoogleCalendar.Tag]? = nil,
        appleCalendarTags: [AppleCalendar.Tag]? = nil
    ) async throws -> CalendarEventListhUsecaseImple {
        let todos = (0..<3).map { int in
            return TodoEvent(uuid: "todo:\(int)", name: "todo")
                |> \.time .~ .at(0)
                |> \.eventTagId .~ .default
        }
        let schedules = (0..<3).map { int in
            return ScheduleEvent(uuid: "sc:\(int)", name: "sc", time: .at(0))
                |> \.eventTagId .~ .default
        }
        let defaultGoogles = (0..<4).map { int in
            return GoogleCalendar.Event(
                "g:\(int)", "google", accountId: "stub@gmail.com", name: "g", colorId: "color", time: .at(0)
            )
            |> \.eventTagId .~ .externalCalendar(serviceId: GoogleCalendarService.id, id: "google")
            |> \.status .~ (int == 3 ? .cancelled : .confirmed)
        }
        let currentTodos = (0..<3).map { int in
            return TodoEvent(uuid: "c-t:\(int)", name: "curent")
                |> \.eventTagId .~ .default
        }
        let uncompletedTodos = (0..<3).map { int in
            return TodoEvent(uuid: "u-t:\(int)", name: "uncompleted")
                |> \.eventTagId .~ .default
                |> \.time .~ .at(0)
                |> \.creatTimeStamp .~ (100-TimeInterval(int))
        }
        let todoUsecase = StubTodoEventUsecase()
        todoUsecase.stubTodoEventsInRange = todos
        todoUsecase.stubCurrentTodoEvents = currentTodos
        todoUsecase.stubUncompletedTodos = uncompletedTodos

        let scheduleUsecase = StubScheduleEventUsecase()
        scheduleUsecase.stubScheduleEventsInRange = schedules

        let googleUsecase = StubGoogleCalendarUsecase()
        googleUsecase.stubEvents = googleEvents ?? defaultGoogles
        if let googleCalendarTags {
            googleUsecase.stubCalendarTags = googleCalendarTags
            googleUsecase.refreshGoogleCalendarEventTags()
        }

        let appleUsecase = StubAppleCalendarUsecase()
        appleUsecase.stubEvents = appleEvents
        if let appleCalendarTags {
            appleUsecase.sendCalendarTags(appleCalendarTags)
        }

        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.prepare()

        _ = try await self.uiSettingUsecase.refreshAppearanceSetting()

        self.eventTagUsecase.addEventTagOffIds(offTagIds)

        return .init(
            todoUsecase: todoUsecase,
            scheduleUsecase: scheduleUsecase,
            googleCalendarUsecase: googleUsecase,
            appleCalendarUsecase: appleUsecase,
            foremostEventUsecase: self.foremostUsecase,
            calendarSettingUsecase: calendarSettingUsecase,
            eventTagUsecase: self.eventTagUsecase,
            uiSettingUsecase: self.uiSettingUsecase
        )
    }
}


// MARK: - calendar events

extension CalendarEventListhUsecaseImpleTests {
    
    @Test func googleCalendarEvent_whenTimeIsAllDay_eventTimeOnCalendarUpperboundIsMinus1Second() {
        // given
        let event = GoogleCalendar.Event("id", "calendar", accountId: "stub@gmail.com", name: "name", colorId: "color", time: .allDay(0..<100, secondsFromGMT: 0))
        
        // when
        let calendarEvent = GoogleCalendarEvent(event, in: TimeZone(abbreviation: "UTC")!)
        
        // then
        let periodRange: Range<TimeInterval>? = switch calendarEvent.eventTimeOnCalendar {
            case .period(let range): range
            default: nil
        }
        #expect(periodRange == (0..<99))
    }
    
    @Test func usecase_getCalendarEvents() async throws {
        // given
        let expect = expectConfirm("이벤트 리스트 제공, todo, schedule, google event")
        let usecase = try await self.makeUsecase()
        
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
        let usecase = try await self.makeUsecase()
        
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
    
    @Test func usecase_includeAppleCalendarEvents() async throws {
        // given
        let expect = expectConfirm("Apple Calendar 이벤트도 포함하여 제공")
        let appleEvents = (0..<2).map { int in
            AppleCalendar.Event(
                eventId: "a:\(int)",
                originalEventId: "a:\(int)",
                calendarId: "apple-cal",
                name: "apple-event",
                eventTime: .at(0)
            )
        }
        let usecase = try await self.makeUsecase(appleEvents: appleEvents)

        // when
        let eventSource = usecase.calendarEvents(in: 0..<10)
        let events = try await self.firstOutput(expect, for: eventSource)

        // then
        let appleEventIds = events?.compactMap { $0 as? AppleCalendarEvent }.map { $0.eventId }
        #expect(appleEventIds == (0..<2).map { "a:\($0)" })
    }

    @Test func usecase_whenOffTagIdUpdated_updateCalendarList() async throws {
        // given
        let expect = expectConfirm("비활성화된 태그 이벤트는 제외")
        expect.count = 4
        expect.timeout = .milliseconds(500)
        let usecase = try await self.makeUsecase()
        
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


// MARK: - 쓰기 가능한 외부 캘린더 이벤트 판정

extension CalendarEventListhUsecaseImpleTests {

    @Test func calendarEvents_googleEventIsWritable_whenCalendarAccessRoleIsWritable() async throws {
        // given
        let expect = expectConfirm("쓰기 가능한 캘린더의 구글 이벤트만 isWritable == true")
        let writableEvent = GoogleCalendar.Event(
            "g:writable", "cal:writable", accountId: "stub@gmail.com", name: "writable", colorId: "color", time: .at(0)
        )
        |> \.eventTagId .~ .externalCalendar(serviceId: GoogleCalendarService.id, id: "cal:writable")
        let readonlyEvent = GoogleCalendar.Event(
            "g:readonly", "cal:readonly", accountId: "stub@gmail.com", name: "readonly", colorId: "color", time: .at(0)
        )
        |> \.eventTagId .~ .externalCalendar(serviceId: GoogleCalendarService.id, id: "cal:readonly")
        let tags = [
            GoogleCalendar.Tag(id: "cal:writable", name: "writable")
                |> \.accessRole .~ .owner
                |> \.ownerId .~ "stub@gmail.com",
            GoogleCalendar.Tag(id: "cal:readonly", name: "readonly")
                |> \.accessRole .~ .reader
                |> \.ownerId .~ "stub@gmail.com"
        ]
        let usecase = try await self.makeUsecase(
            googleEvents: [writableEvent, readonlyEvent], googleCalendarTags: tags, appleCalendarTags: []
        )

        // when
        let eventSource = usecase.calendarEvents(in: 0..<10)
        let events = try await self.firstOutput(expect, for: eventSource)

        // then
        let googleEvents = events?.compactMap { $0 as? GoogleCalendarEvent } ?? []
        let isWritableByEventId = Dictionary(uniqueKeysWithValues: googleEvents.map { ($0.eventId, $0.isWritable) })
        #expect(isWritableByEventId["g:writable"] == true)
        #expect(isWritableByEventId["g:readonly"] == false)
    }

    @Test func calendarEvents_googleEventIsWritable_perAccount_whenSameCalendarIdSharedAcrossAccounts() async throws {
        // given
        let expect = expectConfirm("같은 calendarId 라도 계정별로 쓰기 가능 여부가 갈린다")
        let ownerAccountEvent = GoogleCalendar.Event(
            "g:owner", "shared-cal", accountId: "owner@gmail.com", name: "owner-side", colorId: "color", time: .at(0)
        )
        |> \.eventTagId .~ .externalCalendar(serviceId: GoogleCalendarService.id, id: "shared-cal")
        let readerAccountEvent = GoogleCalendar.Event(
            "g:reader", "shared-cal", accountId: "reader@gmail.com", name: "reader-side", colorId: "color", time: .at(0)
        )
        |> \.eventTagId .~ .externalCalendar(serviceId: GoogleCalendarService.id, id: "shared-cal")
        let tags = [
            GoogleCalendar.Tag(id: "shared-cal", name: "shared-cal")
                |> \.accessRole .~ .owner
                |> \.ownerId .~ "owner@gmail.com",
            GoogleCalendar.Tag(id: "shared-cal", name: "shared-cal")
                |> \.accessRole .~ .reader
                |> \.ownerId .~ "reader@gmail.com"
        ]
        let usecase = try await self.makeUsecase(
            googleEvents: [ownerAccountEvent, readerAccountEvent], googleCalendarTags: tags, appleCalendarTags: []
        )

        // when
        let eventSource = usecase.calendarEvents(in: 0..<10)
        let events = try await self.firstOutput(expect, for: eventSource)

        // then
        let googleEvents = events?.compactMap { $0 as? GoogleCalendarEvent } ?? []
        let isWritableByEventId = Dictionary(uniqueKeysWithValues: googleEvents.map { ($0.eventId, $0.isWritable) })
        #expect(isWritableByEventId["g:owner"] == true)
        #expect(isWritableByEventId["g:reader"] == false)
    }

    @Test func calendarEvents_appleEventIsWritable_whenCalendarTagIsWritable() async throws {
        // given
        let expect = expectConfirm("쓰기 가능한 캘린더의 애플 이벤트만 isWritable == true, 미확인(nil) 태그는 fail-closed")
        let writableEvent = AppleCalendar.Event(
            eventId: "a:writable", originalEventId: "a:writable", calendarId: "cal:writable", name: "writable", eventTime: .at(0)
        )
        let readonlyEvent = AppleCalendar.Event(
            eventId: "a:readonly", originalEventId: "a:readonly", calendarId: "cal:readonly", name: "readonly", eventTime: .at(0)
        )
        let unresolvedEvent = AppleCalendar.Event(
            eventId: "a:unresolved", originalEventId: "a:unresolved", calendarId: "cal:unresolved", name: "unresolved", eventTime: .at(0)
        )
        let tags = [
            AppleCalendar.Tag(id: "cal:writable", name: "writable", colorHex: "hex") |> \.isWritable .~ true,
            AppleCalendar.Tag(id: "cal:readonly", name: "readonly", colorHex: "hex") |> \.isWritable .~ false,
            AppleCalendar.Tag(id: "cal:unresolved", name: "unresolved", colorHex: "hex")
        ]
        let usecase = try await self.makeUsecase(
            appleEvents: [writableEvent, readonlyEvent, unresolvedEvent], googleCalendarTags: [], appleCalendarTags: tags
        )

        // when
        let eventSource = usecase.calendarEvents(in: 0..<10)
        let events = try await self.firstOutput(expect, for: eventSource)

        // then
        let appleEvents = events?.compactMap { $0 as? AppleCalendarEvent } ?? []
        let isWritableByEventId = Dictionary(uniqueKeysWithValues: appleEvents.map { ($0.eventId, $0.isWritable) })
        #expect(isWritableByEventId["a:writable"] == true)
        #expect(isWritableByEventId["a:readonly"] == false)
        #expect(isWritableByEventId["a:unresolved"] == false)
    }

    @Test func calendarEvents_externalEventIsNotWritable_whenCalendarTagsNotLoaded() async throws {
        // given
        let expect = expectConfirm("캘린더 태그가 로드되지 않아도 이벤트 목록은 방출되고, 외부 이벤트는 전부 isWritable == false")
        let appleEvents = (0..<2).map { int in
            AppleCalendar.Event(
                eventId: "a:\(int)", originalEventId: "a:\(int)", calendarId: "apple-cal", name: "apple-event", eventTime: .at(0)
            )
        }
        let usecase = try await self.makeUsecase(appleEvents: appleEvents)

        // when
        let eventSource = usecase.calendarEvents(in: 0..<10)
        let events = try await self.firstOutput(expect, for: eventSource)

        // then
        let googleEvents = events?.compactMap { $0 as? GoogleCalendarEvent } ?? []
        let appleCalendarEvents = events?.compactMap { $0 as? AppleCalendarEvent } ?? []
        #expect(!googleEvents.isEmpty)
        #expect(!appleCalendarEvents.isEmpty)
        #expect(googleEvents.allSatisfy { $0.isWritable == false })
        #expect(appleCalendarEvents.allSatisfy { $0.isWritable == false })
    }
}


// MARK: - all calendar events (태그 필터 미적용)

extension CalendarEventListhUsecaseImpleTests {

    @Test func usecase_allCalendarEvents_includesEventsOfOffTags() async throws {
        // given
        let expect = expectConfirm("태그 필터와 무관하게 전체 이벤트 제공")
        let usecase = try await self.makeUsecase(offTagIds: [.default])

        // when
        let eventSource = usecase.allCalendarEvents(in: 0..<10)
        let events = try await self.firstOutput(expect, for: eventSource)

        // then
        let ids = events?.map { $0.eventId }
        #expect(ids == (0..<3).map { "todo:\($0)"} + (0..<3).map { "sc:\($0)-1" } + (0..<3).map { "g:\($0)" })
    }

    @Test func usecase_calendarEvents_stillExcludesOffTags() async throws {
        // given
        let expect = expectConfirm("기존 조회는 여전히 off 태그 이벤트를 제외")
        let usecase = try await self.makeUsecase(offTagIds: [.default])

        // when
        let eventSource = usecase.calendarEvents(in: 0..<10)
        let events = try await self.firstOutput(expect, for: eventSource)

        // then
        let ids = events?.map { $0.eventId }
        #expect(ids == (0..<3).map { "g:\($0)" })
    }
}


// MARK: - current todo

extension CalendarEventListhUsecaseImpleTests {
    
    @Test func usecase_provideCurrentTodoList() async throws {
        // given
        let expect = expectConfirm("current todo 정보 제공")
        let usecase = try await self.makeUsecase()
        
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
        let usecase = try await self.makeUsecase()
        
        // when
        let todoLists = try await self.outputs(expect, for: usecase.currentTodoEvents()) {
            
            Task {
                try await self.foremostUsecase.update(foremost: .init("c-t:1", true))
                
                try await self.foremostUsecase.update(foremost: .init("c-t:0", false))
                
                try await self.foremostUsecase.remove()
            }
        }
        
        // then
        let foresmotTodoIds = todoLists
                .map { ts in ts.filter { $0.isForemost } }
                .map { ts in ts.map { $0.eventId } }
        #expect(foresmotTodoIds == [
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
        let usecase = try await self.makeUsecase()
        
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

// MARK: - uncompleted todo

extension CalendarEventListhUsecaseImpleTests {
    
    @Test func usecase_provideUncompletedTodos() async throws {
        // given
        let expect = expectConfirm("완료되지않은 할일 리스트 제공")
        let usecase = try await self.makeUsecase()
        
        // when
        let todos = try await self.firstOutput(expect, for: usecase.uncompletedTodos())
        
        // then
        let ids = todos?.map { $0.eventId }
        #expect(ids == (0..<3).reversed().map { "u-t:\($0)" })
    }
    
    @Test func usecase_provideUncompletedTodoListWithIsForemost() async throws {
        // given
        let expect = expectConfirm("완료되지않은 할일 리스트 제공시 foremost 여부와 같이 제공")
        expect.count = 4
        let usecase = try await self.makeUsecase()
        
        // when
        let todoLists = try await self.outputs(expect, for: usecase.uncompletedTodos()) {
            
            Task {
                try await self.foremostUsecase.update(foremost: .init("u-t:1", true))
                
                try await self.foremostUsecase.update(foremost: .init("u-t:0", false))
                
                try await self.foremostUsecase.remove()
            }
        }
        
        // then
        let foresmotTodoIds = todoLists
                .map { ts in ts.filter { $0.isForemost } }
                .map { ts in ts.map { $0.eventId } }
        #expect(foresmotTodoIds == [
            [],
            ["u-t:1"],
            ["u-t:0"],
            []
        ])
    }
    
    @Test func usecase_provideUncompletedTodo_withoutTagOff() async throws {
        // given
        let expect = expectConfirm("완료되지않은 할일 리스트 제공시 tagId off된 항목 제외")
        expect.count = 3
        let usecase = try await self.makeUsecase()
        
        // when
        let todoLists = try await self.outputs(expect, for: usecase.uncompletedTodos()) {
            
            self.eventTagUsecase.toggleEventTagIsOnCalendar(.default)
            self.eventTagUsecase.toggleEventTagIsOnCalendar(.default)
        }
        
        // then
        let allTodoIds = (0..<3).reversed().map { "u-t:\($0)" }
        let idLists = todoLists.map { ts in ts.map { $0.eventId } }
        #expect(idLists == [
            allTodoIds,
            [],
            allTodoIds
        ])
    }
    
    @Test func usecase_provideUncompletedTodoList_byShowOption() async throws {
        // given
        let expect = expectConfirm("완료되지않은 할일 리스트 제공시 노출 옵션 꺼져있으면 빈배열 반환")
        expect.count = 3
        let usecase = try await self.makeUsecase()
        
        // when
        let todoLists = try await self.outputs(expect, for: usecase.uncompletedTodos()) {
            let params = EditCalendarAppearanceSettingParams()
            
            _ = try self.uiSettingUsecase.changeCalendarAppearanceSetting(
                params |> \.showUncompletedTodos .~ false
            )
            _ = try self.uiSettingUsecase.changeCalendarAppearanceSetting(
                params |> \.showUncompletedTodos .~ true
            )
        }
        
        // then
        let allTodoIds = (0..<3).reversed().map { "u-t:\($0)" }
        let idLists = todoLists.map { ts in ts.map { $0.eventId } }
        #expect(idLists == [
            allTodoIds,
            [],
            allTodoIds
        ])
    }
}
