//
//  TodayAndNextWidgetViewModelProviderTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 12/20/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes
import UnitTestHelpKit
import TestDoubles


// MARK: - TodayAndNextWidgetViewModelBuilderTests

final class TodayAndNextWidgetViewModelBuilderTests {
    
    private let refDate = Date(timeIntervalSince1970: 0)
 
    private func makeBuilder() -> TodayAndNextWidgetViewModelBuilder {
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultDark, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "holi", default: "def")
        )
        return TodayAndNextWidgetViewModelBuilder(
            max: 4.0, daysRangeSize: 10,
            kst, setting
        )
    }
}

extension TodayAndNextWidgetViewModelBuilderTests {
    
    // today model
    @Test func builder_provideTodayModel() {
        // given
        let builder = self.makeBuilder()
        
        // when
        let model = builder.build(refDate, .init())
        
        // then
        let today = model.left.rows.first as? TodayAndNextWidgetViewModel.TodayModel
        #expect(model.left.rows.count == 1)
        #expect(model.right.rows.count == 0)
        #expect(today?.weekOfDay == "Thursday")
        #expect(today?.day == 1)
    }
    
    // fill left with current todo
    @Test func builder_provideLeftPageWithCurrentTodo() {
        // given
        let builder = self.makeBuilder()
        let currents = makeCurrentTodo(3)
        let events = CalendarEvents() |> \.currentTodos .~ currents
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        var lefts = model.left.rows
        let today = lefts.removeFirst()
        #expect(today is TodayAndNextWidgetViewModel.TodayModel)
        #expect(lefts.count == 3)
        let currentTodos = lefts
            .compactMap { $0 as? TodayAndNextWidgetViewModel.EventModel }
            .compactMap { $0.cvm as? TodoEventCellViewModel }
            .filter { $0.eventTimeRawValue == nil }
        #expect(lefts.count == currentTodos.count)
    }
    
    // fill left with current todo with summarized
    @Test func builder_provideLeftPageWithCurrentTodoWithSummarized() throws {
        // given
        let builder = self.makeBuilder()
        let currents = makeCurrentTodo(4)
        let events = CalendarEvents() |> \.currentTodos .~ currents
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let lefts = model.left.rows
        try #require(lefts.count == 4)
        
        let today = lefts[0] as? TodayAndNextWidgetViewModel.TodayModel
        #expect(today != nil)
        let currentTodo1 = lefts[1] as? TodayAndNextWidgetViewModel.EventModel
        #expect(currentTodo1?.cvm is TodoEventCellViewModel == true)
        let currentTodo2 = lefts[2] as? TodayAndNextWidgetViewModel.EventModel
        #expect(currentTodo2?.cvm is TodoEventCellViewModel == true)
        let summary = lefts[3] as? TodayAndNextWidgetViewModel.MultipleEventsSummaryModel
        #expect(summary?.tags == [.custom("t:2"), .custom("t:3")])
        #expect(summary?.todoCount == 2)
    }
    
    // fill left with today all day event
    @Test func builder_provideLeftPageWitTodayAlldayEvent() throws {
        // given
        let builder = self.makeBuilder()
        let allDayEvent = makeAllDayTodo(0..<3, offset: 0)
        let events = CalendarEvents() |> \.eventWithTimes .~ allDayEvent
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let lefts = model.left.rows
        try #require(lefts.count == 4)
        
        let today = lefts[0] as? TodayAndNextWidgetViewModel.TodayModel
        #expect(today != nil)
        
        let todo1 = lefts[1] as? TodayAndNextWidgetViewModel.EventModel
        #expect(todo1?.cvm.isAlldayEvent == true)
        let todo2 = lefts[2] as? TodayAndNextWidgetViewModel.EventModel
        #expect(todo2?.cvm.isAlldayEvent == true)
        let todo3 = lefts[3] as? TodayAndNextWidgetViewModel.EventModel
        #expect(todo3?.cvm.isAlldayEvent == true)
    }
    
    // fill left with today all day event with summarized
    @Test func builder_provideLeftPageWithTodayAlldayEventWithSummarized() throws {
        // given
        let builder = self.makeBuilder()
        let allDayEvent = makeAllDayTodo(0..<4, offset: 0)
        let events = CalendarEvents() |> \.eventWithTimes .~ allDayEvent
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let lefts = model.left.rows
        try #require(lefts.count == 4)
        
        let today = lefts[0] as? TodayAndNextWidgetViewModel.TodayModel
        #expect(today != nil)
        
        let todo1 = lefts[1] as? TodayAndNextWidgetViewModel.EventModel
        #expect(todo1?.cvm.isAlldayEvent == true)
        let todo2 = lefts[2] as? TodayAndNextWidgetViewModel.EventModel
        #expect(todo2?.cvm.isAlldayEvent == true)
        let summary = lefts[3] as? TodayAndNextWidgetViewModel.MultipleEventsSummaryModel
        #expect(summary?.tags == [.custom("t:2"), .custom("t:3")])
        #expect(summary?.todoCount == 2)
    }
    
    // fill left with today events
    @Test func builder_provideLeftPageWith_todayRemainEvents() throws {
        // given
        let builder = self.makeBuilder()
        let schedules = makeSchedule(-10..<2, offset: 0)
        let events = CalendarEvents() |> \.eventWithTimes .~ schedules
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let lefts = model.left.rows
        try #require(lefts.count == 3)
        
        let today = lefts[0] as? TodayAndNextWidgetViewModel.TodayModel
        #expect(today != nil)
        
        let ev1 = lefts[1] as? TodayAndNextWidgetViewModel.EventModel
        #expect(ev1?.cvm.name == "sc:0")
        #expect(ev1?.rowWeight == 1)
        let ev2 = lefts[2] as? TodayAndNextWidgetViewModel.EventModel
        #expect(ev2?.cvm.name == "sc:1")
        #expect(ev2?.rowWeight == 1)
    }
    
    // fill left with today events without summarized
    @Test func builder_provideLeftPageWith_todayRemainEventsWithoutSummarized() throws {
        // given
        let builder = self.makeBuilder()
        let schedules = makeSchedule(-10..<10, offset: 0)
        let events = CalendarEvents() |> \.eventWithTimes .~ schedules
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let lefts = model.left.rows
        try #require(lefts.count == 3)
        
        let today = lefts[0] as? TodayAndNextWidgetViewModel.TodayModel
        #expect(today != nil)
        
        let ev1 = lefts[1] as? TodayAndNextWidgetViewModel.EventModel
        #expect(ev1?.cvm.name == "sc:0")
        #expect(ev1?.rowWeight == 1)
        let ev2 = lefts[2] as? TodayAndNextWidgetViewModel.EventModel
        #expect(ev2?.cvm.name == "sc:1")
        #expect(ev2?.rowWeight == 1)
    }
    
    @Test func builder_provideLeftPage() throws {
        // given
        let builder = self.makeBuilder()
        let alldayEvents: [any CalendarEvent] = makeAllDayTodo(1..<2, offset: 0)
        let schedule: [any CalendarEvent] = makeSchedule(2..<3, offset: 0)
        let events = CalendarEvents()
            |> \.currentTodos .~ makeCurrentTodo(1)
            |> \.eventWithTimes .~ (alldayEvents+schedule)
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let lefts = model.left.rows
        try #require(lefts.count == 3)
        
        let today = lefts[0] as? TodayAndNextWidgetViewModel.TodayModel
        #expect(today != nil)
        
        #expect((lefts[1] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "current:0")
        #expect((lefts[2] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "allday:1")
    }
}

extension TodayAndNextWidgetViewModelBuilderTests {
    
    // fill right with today remain events
    @Test func builder_fillRightWithTodayRemainEvents() throws {
        // given
        let builder = self.makeBuilder()
        let remain = makeSchedule(0..<2+4, offset: 0)
        let events = CalendarEvents() |> \.eventWithTimes .~ remain
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let rights = model.right.rows
        try #require(rights.count == 4)
        
        let names = rights
            .compactMap { $0 as? TodayAndNextWidgetViewModel.EventModel }
            .map { $0.cvm.name }
        #expect(names == [
            "sc:2", "sc:3", "sc:4", "sc:5"
        ])
    }
    
    // fill right with today remain with summarized
    @Test func builder_fillRightWithTodayRemainEventsWithSummarized() throws {
        // given
        let builder = self.makeBuilder()
        let remain = makeSchedule(0..<2+5, offset: 0)
        let events = CalendarEvents() |> \.eventWithTimes .~ remain
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let rights = model.right.rows
        try #require(rights.count == 4)
        
        #expect(rights[0] is TodayAndNextWidgetViewModel.EventModel == true)
        #expect(rights[1] is TodayAndNextWidgetViewModel.EventModel == true)
        #expect(rights[2] is TodayAndNextWidgetViewModel.EventModel == true)
        
        let summary = rights[3] as? TodayAndNextWidgetViewModel.MultipleEventsSummaryModel
        #expect(summary?.tags == [.default, .default])
        #expect(summary?.todoCount == 0)
    }
    
    // fill right with tomorrow events
    @Test func builder_fillRightWithTomorrowEvents() throws {
        // given
        let builder = self.makeBuilder()
        let today = makeSchedule(0..<2, offset: 0)
        let tommorrow = makeSchedule(10..<13, offset: 1)
        let events = CalendarEvents() |> \.eventWithTimes .~ (today + tommorrow)
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let rights = model.right.rows
        try #require(rights.count == 4)
        
        let date = rights[0] as? TodayAndNextWidgetViewModel.DateModel
        #expect(date != nil)
        
        #expect((rights[1] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:10")
        #expect((rights[2] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:11")
        #expect((rights[3] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:12")
    }
    
    // fill right with tomorrow event without summarized
    @Test func builder_fillRightWithTomorrowEventsWithoutSummarized() throws {
        // given
        let builder = self.makeBuilder()
        let today = makeSchedule(0..<2, offset: 0)
        let tommorrow = makeSchedule(10..<20, offset: 1)
        let events = CalendarEvents() |> \.eventWithTimes .~ (today + tommorrow)
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let rights = model.right.rows
        try #require(rights.count == 4)
        
        let date = rights[0] as? TodayAndNextWidgetViewModel.DateModel
        #expect(date != nil)
        
        #expect((rights[1] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:10")
        #expect((rights[2] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:11")
        #expect((rights[3] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:12")
    }
    
    // fill right with today remain + tomorrow
    @Test func builder_fillRightWithTodayRemainAndTomorrow() throws {
        // given
        let builder = self.makeBuilder()
        let remain = makeSchedule(0..<2+1, offset: 0)
        let tomorrow = makeSchedule(10..<12, offset: 1)
        let events = CalendarEvents() |> \.eventWithTimes .~ (remain + tomorrow)
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let rights = model.right.rows
        try #require(rights.count == 4)
        
        #expect((rights[0] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:2")
        #expect(rights[1] is TodayAndNextWidgetViewModel.DateModel == true)
        #expect((rights[2] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:10")
        #expect((rights[3] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:11")
    }
    
    // fill right with today remain + tomorrow without summarized
    @Test func builder_fillRightWithTodayRemainAndTomorrowWithoutSummarized() throws {
        // given
        let builder = self.makeBuilder()
        let remain = makeSchedule(0..<2+1, offset: 0)
        let tomorrow = makeSchedule(10..<20, offset: 1)
        let events = CalendarEvents() |> \.eventWithTimes .~ (remain + tomorrow)
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let rights = model.right.rows
        try #require(rights.count == 4)
        
        #expect((rights[0] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:2")
        #expect(rights[1] is TodayAndNextWidgetViewModel.DateModel == true)
        #expect((rights[1] as? TodayAndNextWidgetViewModel.DateModel)?.dateText == "Tomorrow")
        #expect((rights[2] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:10")
        #expect((rights[3] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:11")
    }
    
    // fill right with today remain + without tomorrow if no space
    @Test func builder_fillRightWithTodayRemainAndWithoutTomorrowIfNoSpace() throws {
        // given
        let builder = self.makeBuilder()
        let remain = makeSchedule(0..<2+4, offset: 0)
        let tomorrow = makeSchedule(10..<20, offset: 1)
        let events = CalendarEvents() |> \.eventWithTimes .~ (remain + tomorrow)
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let rights = model.right.rows
        try #require(rights.count == 4)
        
        let names = rights
            .compactMap { $0 as? TodayAndNextWidgetViewModel.EventModel }
            .map { $0.cvm.name }
        #expect(names == [
            "sc:2", "sc:3", "sc:4", "sc:5"
        ])
    }
    
    // fill right with tomorrow and other day event
    @Test func builder_fillRightTomorrowAndOtherDayEvent() throws {
        // given
        let builder = self.makeBuilder()
        let today: [any CalendarEvent] = makeSchedule(0..<2, offset: 0)
        let tomorrow: [any CalendarEvent] = makeSchedule(10..<11, offset: 1)
        let otherDay: [any CalendarEvent] = makeSchedule(100..<101, offset: 2)
        let events = CalendarEvents() |> \.eventWithTimes .~ (today + tomorrow + otherDay)
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let rights = model.right.rows
        try #require(rights.count == 4)
        
        #expect((rights[0] as? TodayAndNextWidgetViewModel.DateModel)?.dateText == "Tomorrow")
        #expect((rights[1] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:10")
        #expect((rights[2] as? TodayAndNextWidgetViewModel.DateModel)?.dateText == "Jan 03 (Sat)")
        #expect((rights[3] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:100")
    }
    
    // fill right with tomorrow and other day with summarized
    @Test func builder_fillRightTomorrowAndOtherDayEventWithSummarized() throws {
        // given
        let builder = self.makeBuilder()
        let today: [any CalendarEvent] = makeSchedule(0..<2, offset: 0)
        let tomorrow: [any CalendarEvent] = makeSchedule(10..<11, offset: 1)
        let otherDay: [any CalendarEvent] = makeSchedule(100..<104, offset: 2)
        let events = CalendarEvents() |> \.eventWithTimes .~ (today + tomorrow + otherDay)
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let rights = model.right.rows
        try #require(rights.count == 4)
        
        #expect((rights[0] as? TodayAndNextWidgetViewModel.DateModel)?.dateText == "Tomorrow")
        #expect((rights[1] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:10")
        #expect((rights[2] as? TodayAndNextWidgetViewModel.DateModel)?.dateText == "Jan 03 (Sat)")
        let summary = rights[3] as? TodayAndNextWidgetViewModel.MultipleEventsSummaryModel
        #expect(summary?.tags.count == 4)
        #expect(summary?.todoCount == 0)
    }
    
    // fill right with other day events
    @Test func builder_fillRightWithOtherDayEvents() throws {
        // given
        let builder = self.makeBuilder()
        let events = CalendarEvents() |> \.eventWithTimes .~ makeSchedule(100..<103, offset: 2)
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        let rights = model.right.rows
        try #require(rights.count == 4)
        
        #expect((rights[0] as? TodayAndNextWidgetViewModel.DateModel)?.dateText == "Jan 03 (Sat)")
        #expect((rights[1] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:100")
        #expect((rights[2] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:101")
        #expect((rights[3] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:102")
    }
}

extension TodayAndNextWidgetViewModelBuilderTests {
    
    // refreshAfter is next event time without allday event
    @Test func builder_provideTodayNextRefreshDate_wthoutAllDayEvent() {
        // given
        let builder = self.makeBuilder()
        let allDay: [any CalendarEvent] = makeAllDayTodo(0..<1, offset: 0)
        let today: [any CalendarEvent] = makeSchedule(1..<2, offset: 0)
        let events = CalendarEvents() |> \.eventWithTimes .~ (allDay + today)
        
        // when
        let model = builder.build(refDate, events)
        
        // then
        #expect(model.refreshAfter == 1)
    }
}


// MARK: - TodayAndNextWidgetViewModelProviderTests

struct TodayAndNextWidgetViewModelProviderTests {
    
    private func makeProvider(
        targetTags: [EventTagId]? = nil,
        excludeAllDay: Bool = false
    ) -> TodayAndNextWidgetViewModelProvider {
        
        return TodayAndNextWidgetViewModelProvider(
            targetEventTagIds: targetTags,
            excludeAllDayEvents: excludeAllDay,
            eventsFetchUsecase: PrivateStubCalendarEventsFetchUsecase(),
            calendarSettingRepository: StubCalendarSettingRepository(),
            appSettingRepository: StubAppSettingRepository(),
            localeProvider: Locale.current
        )
    }
}

extension TodayAndNextWidgetViewModelProviderTests {
    
    @Test func provider_provideModel() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let model = try await provider.getViewModel(for: Date(timeIntervalSince1970: 0))
        
        // then
        let rows = model.left.rows + model.right.rows
        try #require(rows.count == 6)
        #expect(rows[0] is TodayAndNextWidgetViewModel.TodayModel == true)
        #expect((rows[1] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "allday:0")
        #expect((rows[2] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:10")
        #expect((rows[3] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:11")
        #expect((rows[4] as? TodayAndNextWidgetViewModel.DateModel)?.dateText == "Tomorrow")
        #expect((rows[5] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "allday:1")
    }
    
    @Test func provider_provideWithTargetEvents() async throws {
        // given
        let provider = self.makeProvider(targetTags: [.custom("t:1")])
        
        // when
        let model = try await provider.getViewModel(for: Date(timeIntervalSince1970: 0))
        
        // then
        let rows = model.left.rows + model.right.rows
        try #require(rows.count == 3)
        
        #expect(rows[0] is TodayAndNextWidgetViewModel.TodayModel == true)
        #expect((rows[1] as? TodayAndNextWidgetViewModel.DateModel)?.dateText == "Tomorrow")
        #expect((rows[2] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "allday:1")
    }
    
    @Test func provider_provideWithExcludeAllDayEvents() async throws {
        // given
        let provider = self.makeProvider(excludeAllDay: true)
        
        // when
        let model = try await provider.getViewModel(for: Date(timeIntervalSince1970: 0))
        
        // then
        let rows = model.left.rows + model.right.rows
        try #require(rows.count == 3)
        
        #expect(rows[0] is TodayAndNextWidgetViewModel.TodayModel == true)
        #expect((rows[1] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:10")
        #expect((rows[2] as? TodayAndNextWidgetViewModel.EventModel)?.cvm.name == "sc:11")
    }
}

// MARK: - doubles

private func makeCurrentTodo(_ size: Int) -> [TodoCalendarEvent] {
    return (0..<size).map { int in
        return TodoCalendarEvent(
            current: TodoEvent.dummy(int)
                |> \.name .~ "current:\(int)"
                |> \.eventTagId .~ .custom("t:\(int)"),
            isForemost: false
        )
        
    }
}

private let kst = TimeZone(abbreviation: "KST")!

private func makeAllDayTodo(_ range: Range<Int>, offset: Int) -> [TodoCalendarEvent] {
    let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ kst
    let day = calendar.addDays(offset, from: Date(timeIntervalSince1970: 0))!
    let start = calendar.startOfDay(for: day); let end = calendar.endOfDay(for: day)!
    let time = EventTime.allDay(start.timeIntervalSince1970..<end.timeIntervalSince1970, secondsFromGMT: TimeInterval(kst.secondsFromGMT()))
    return range.map { int in
        let todo = TodoEvent.dummy(int)
            |> \.name .~ "allday:\(int)"
            |> \.time .~ time
            |> \.eventTagId .~ .custom("t:\(int)")
        return TodoCalendarEvent(todo, in: kst)
    }
}

private func makeSchedule(_ range: Range<Int>, offset: Int) -> [ScheduleCalendarEvent] {
    let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ kst
    let day = calendar.addDays(offset, from: Date(timeIntervalSince1970: 0))!
    return range.map { int in
        let schedule = ScheduleEvent(
            uuid: "sc:\(int)", name: "sc:\(int)",
            time: .at(day.timeIntervalSince1970 + TimeInterval(int))
        )
        return ScheduleCalendarEvent.events(from: schedule, in: kst).first!
    }
}

private final class PrivateStubCalendarEventsFetchUsecase: StubCalendarEventsFetchUescase {
    
    override func fetchEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone,
        withoutOffTagIds: Bool
    ) async throws -> CalendarEvents {
        
        let todayAll: [any CalendarEvent] = makeAllDayTodo(0..<1, offset: 0)
        let tomorrowAll: [any CalendarEvent] = makeAllDayTodo(1..<2, offset: 1)
        
        let schedules: [any CalendarEvent] = makeSchedule(10..<12, offset: 0)
        
        let events = CalendarEvents()
            |> \.eventWithTimes .~ (todayAll + tomorrowAll + schedules)
        return events
    }
}
