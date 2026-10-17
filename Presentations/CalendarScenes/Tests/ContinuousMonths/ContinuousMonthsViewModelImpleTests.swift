//
//  ContinuousMonthsViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import CalendarScenes
import CalendarPresentation


final class ContinuousMonthsViewModelImpleTests: PublisherWaitable, AsyncEffectWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()
    private let stubSettingUsecase = StubCalendarSettingUsecase()
    private let stubTagUsecase = StubEventTagUsecase()
    private let stubUISettingUsecase = StubUISettingUsecase()
    private let spyEventListUsecase = PrivateSpyEventListUsecase()
    private let spyListener = SpyListener()
    private let kst = TimeZone(abbreviation: "KST")!

    private func makeViewModel(
        focus: CalendarMonth = .init(year: 2023, month: 9),
        holidays: [Int: [Holiday]] = [:],
        events: [any CalendarEvent] = [],
        isHolidayOff: Bool = false,
        showUnderLineOnEventDay: Bool = false
    ) -> ContinuousMonthsViewModelImple {
        self.stubSettingUsecase.prepare()
        _ = self.stubUISettingUsecase.loadSavedAppearanceSetting()
        if showUnderLineOnEventDay {
            let params = EditCalendarAppearanceSettingParams() |> \.showUnderLineOnEventDay .~ true
            _ = try? self.stubUISettingUsecase.changeCalendarAppearanceSetting(params)
        }
        if isHolidayOff {
            self.stubTagUsecase.toggleEventTagIsOnCalendar(.holiday)
        }
        self.spyEventListUsecase.mockEvents.send(events)
        let calendarUsecase = PrivateStubCalendarUsecase(
            settingUsecase: self.stubSettingUsecase,
            holidayUsecase: StubHolidayUsecase(holidays: holidays)
        )
        let viewModel = ContinuousMonthsViewModelImple(
            initialMonth: focus,
            calendarUsecase: calendarUsecase,
            calendarSettingUsecase: self.stubSettingUsecase,
            eventListUsecase: self.spyEventListUsecase,
            eventTagUsecase: self.stubTagUsecase,
            uiSettingUsecase: self.stubUISettingUsecase
        )
        viewModel.attachListener(self.spyListener)
        return viewModel
    }

    private func firstSections(
        _ viewModel: ContinuousMonthsViewModelImple,
        _ action: (() async throws -> Void)? = nil
    ) async throws -> [ContinuousMonthSection] {
        let expect = self.expectConfirm("섹션 방출")
        let source = viewModel.sections.filter { !$0.isEmpty }
        return try await self.firstOutput(expect, for: source, action) ?? []
    }

    private func month(_ year: Int, _ month: Int) -> CalendarMonth {
        return .init(year: year, month: month)
    }
}


// MARK: - 포커스 월 중심 버퍼

extension ContinuousMonthsViewModelImpleTests {

    @Test func viewModel_provideFiveSectionsAroundFocusedMonth() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        let sections = try await self.firstSections(viewModel)

        // then
        #expect(sections.map { $0.month } == [
            month(2023, 7), month(2023, 8), month(2023, 9), month(2023, 10), month(2023, 11)
        ])
    }

    @Test func viewModel_sectionStartsWithWeekContainingFirstDay() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        let sections = try await self.firstSections(viewModel)

        // then
        #expect(sections.map { $0.weeks.first?.id } == [
            "2023-6-25-2023-7-1",
            "2023-7-30-2023-8-5",
            "2023-8-27-2023-9-2",
            "2023-10-1-2023-10-7",
            "2023-10-29-2023-11-4"
        ])
        #expect(sections.map { $0.weeks.count } == [5, 4, 5, 4, 5])
    }

    @Test func viewModel_boundaryWeekAppearsOnce() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        let sections = try await self.firstSections(viewModel)

        // then
        let allIds = sections.flatMap { $0.weeks.map { $0.id } }
        #expect(allIds.count == Set(allIds).count)
        #expect(sections[1].weeks.last?.id == "2023-8-20-2023-8-26")
        #expect(sections[4].weeks.last?.id == "2023-11-26-2023-12-2")
    }

    @Test func viewModel_sectionsAcrossYearBoundary() async throws {
        // given
        let viewModel = self.makeViewModel(focus: .init(year: 2023, month: 12))

        // when
        let sections = try await self.firstSections(viewModel)

        // then
        #expect(sections.map { $0.month } == [
            month(2023, 10), month(2023, 11), month(2023, 12), month(2024, 1), month(2024, 2)
        ])
        #expect(sections[3].weeks.first?.id == "2023-12-31-2024-1-6")
    }

    @Test func viewModel_whenFirstWeekDayChanged_rebuildSections() async throws {
        // given
        let viewModel = self.makeViewModel()
        var emitted: [[ContinuousMonthSection]] = []
        viewModel.sections
            .sink { emitted.append($0) }
            .store(in: &self.cancelBag)
        try await self.waitEffect("첫 섹션 도착") { emitted.count == 1 }

        // when
        self.stubSettingUsecase.updateFirstWeekDay(.monday)
        try await self.waitEffect("월요일 기준 섹션 도착") {
            emitted.last.map { self.sectionStartWeekDays($0) == Set([2]) } == true
        }
        try await Task.sleep(for: .milliseconds(50))

        // then
        let emittedAfterChange = emitted.dropFirst()
        #expect(emittedAfterChange.allSatisfy { self.sectionStartWeekDays($0).count == 1 })
        #expect(emitted.last?[2].weeks.first?.id == "2023-8-28-2023-9-3")
    }

    private func sectionStartWeekDays(_ sections: [ContinuousMonthSection]) -> Set<Int> {
        let calendar = Calendar(identifier: .gregorian)
        return Set(sections.compactMap { section -> Int? in
            guard let day = section.weeks.first?.days.first,
                  let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))
            else { return nil }
            return calendar.component(.weekday, from: date)
        })
    }
}


// MARK: - 요일·오늘

extension ContinuousMonthsViewModelImpleTests {

    @Test func viewModel_provideWeekDaysByFirstWeekDay() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        let expect = self.expectConfirm("요일 목록")
        expect.count = 2
        let weekDays = try await self.outputs(expect, for: viewModel.weekDays) {
            self.stubSettingUsecase.updateFirstWeekDay(.monday)
        }

        // then
        #expect(weekDays.map { $0.first?.identifier } == ["sunday", "moday"])
    }

    @Test func viewModel_provideTodayIdentifier() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        let today = try await self.firstOutput(self.expectConfirm("오늘"), for: viewModel.todayIdentifier)

        // then
        #expect(today == "2023-9-10")
    }
}


// MARK: - 포커스 이동

extension ContinuousMonthsViewModelImpleTests {

    @Test func viewModel_whenChangeFocusedMonth_shiftBuffer_withoutNotifyListener() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstSections(viewModel)

        // when
        let expect = self.expectConfirm("외부 포커스 이동 뒤 섹션")
        let source = viewModel.sections.filter { $0.first?.month == CalendarMonth(year: 2023, month: 8) }
        let sections = try await self.firstOutput(expect, for: source) {
            viewModel.changeFocusedMonth(to: .init(year: 2023, month: 10))
        }
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(sections?.map { $0.month.month } == [8, 9, 10, 11, 12])
        #expect(self.spyListener.didScrollToMonth == nil)
    }

    @Test func viewModel_whenScrolledToMonth_shiftBufferAndNotifyListener() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstSections(viewModel)

        // when
        let expect = self.expectConfirm("스냅 뒤 섹션")
        let source = viewModel.sections.filter { $0.first?.month == CalendarMonth(year: 2023, month: 8) }
        let sections = try await self.firstOutput(expect, for: source) {
            viewModel.scrolled(to: .init(year: 2023, month: 10))
        }

        // then
        #expect(sections?.map { $0.month.month } == [8, 9, 10, 11, 12])
        #expect(self.spyListener.didScrollToMonth == CalendarMonth(year: 2023, month: 10))
    }

    @Test func viewModel_whenChangeFocusedMonthToSameMonth_notEmitSections() async throws {
        // given
        let viewModel = self.makeViewModel()
        var emitted: [[ContinuousMonthSection]] = []
        viewModel.sections
            .sink { emitted.append($0) }
            .store(in: &self.cancelBag)
        try await self.waitEffect("첫 섹션 도착") { emitted.count == 1 }

        // when
        viewModel.changeFocusedMonth(to: .init(year: 2023, month: 9))
        viewModel.changeFocusedMonth(to: .init(year: 2023, month: 9))
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(emitted.count == 1)
    }
}


// MARK: - 이벤트·공휴일

extension ContinuousMonthsViewModelImpleTests {

    @Test func viewModel_provideEventStackForBufferWeeks() async throws {
        // given
        let julyEvent = StubCalendarEvent("ev-7-5", self.dayRange(2023, 7, 5))
        let novemberEvent = StubCalendarEvent("ev-11-28", self.dayRange(2023, 11, 28))
        let viewModel = self.makeViewModel(events: [julyEvent, novemberEvent], showUnderLineOnEventDay: true)
        _ = try await self.firstSections(viewModel)

        // when
        let julyStack = try await self.firstOutput(
            self.expectConfirm("7월 주 스택"), for: viewModel.eventStack(at: "2023-7-2-2023-7-8")
        )
        let novemberStack = try await self.firstOutput(
            self.expectConfirm("11월 주 스택"), for: viewModel.eventStack(at: "2023-11-26-2023-12-2")
        )

        // then
        #expect(julyStack?.linesStack.flatMap { $0 }.map { $0.event.eventId } == ["ev-7-5"])
        #expect(julyStack?.shouldShowEventLinesDays == [5])
        #expect(novemberStack?.linesStack.flatMap { $0 }.map { $0.event.eventId } == ["ev-11-28"])
        let expectedLower = self.dayRange(2023, 6, 25).lowerBound
        let expectedUpper = self.dayRange(2023, 12, 2).upperBound
        let requestedRanges = self.spyEventListUsecase.didRequestRanges
        #expect(requestedRanges.count == 5)
        #expect(requestedRanges.map { $0.lowerBound }.min() == expectedLower)
        #expect(requestedRanges.map { $0.upperBound }.max().map { abs($0 - expectedUpper) < 1 } == true)
    }

    @Test func viewModel_whenBufferShifts_keepEventStackOfOverlappingMonths() async throws {
        // given
        let viewModel = self.makeViewModel()
        var septemberWeekEmitCount = 0
        viewModel.eventsPerDay(at: "2023-9-10-2023-9-16")
            .sink { _ in septemberWeekEmitCount += 1 }
            .store(in: &self.cancelBag)
        try await self.waitEffect("9월 주 첫 스택") { septemberWeekEmitCount == 1 }

        // when
        let shifted = viewModel.sections.filter { $0.first?.month == CalendarMonth(year: 2023, month: 8) }
        _ = try await self.firstOutput(self.expectConfirm("한 달 옮긴 섹션"), for: shifted) {
            viewModel.scrolled(to: .init(year: 2023, month: 10))
        }
        _ = try await self.firstOutput(
            self.expectConfirm("새로 들어온 12월 주 스택"), for: viewModel.eventsPerDay(at: "2023-12-10-2023-12-16")
        )
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(septemberWeekEmitCount == 1)
    }

    @Test func viewModel_whenBufferShifts_provideEventStackForEnteredMonth() async throws {
        // given
        let decemberEvent = StubCalendarEvent("ev-12-13", self.dayRange(2023, 12, 13))
        let viewModel = self.makeViewModel(events: [decemberEvent])
        _ = try await self.firstSections(viewModel)

        // when
        viewModel.scrolled(to: .init(year: 2023, month: 10))
        let source = viewModel.eventStack(at: "2023-12-10-2023-12-16").filter { !$0.linesStack.isEmpty }
        let stack = try await self.firstOutput(self.expectConfirm("12월 주 스택"), for: source)

        // then
        #expect(stack?.linesStack.flatMap { $0 }.map { $0.event.eventId } == ["ev-12-13"])
    }

    @Test func viewModel_whenEventsChanged_updateEventStack() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstSections(viewModel)
        let newEvent = StubCalendarEvent("ev-9-12", self.dayRange(2023, 9, 12))

        // when
        let source = viewModel.eventStack(at: "2023-9-10-2023-9-16").filter { !$0.linesStack.isEmpty }
        let stack = try await self.firstOutput(self.expectConfirm("바뀐 이벤트 반영"), for: source) {
            self.spyEventListUsecase.mockEvents.send([newEvent])
        }

        // then
        #expect(stack?.linesStack.flatMap { $0 }.map { $0.event.eventId } == ["ev-9-12"])
    }

    @Test func viewModel_boundaryWeekHolidayCountedOnce() async throws {
        // given
        let holiday = Holiday(uuid: "hd", dateString: "2023-08-31", name: "boundary-holiday")
        let viewModel = self.makeViewModel(holidays: [2023: [holiday]])

        // when
        let eventsPerDay = try await self.settledEventsPerDay(viewModel, at: "2023-8-27-2023-9-2")

        // then
        let thursdayEvents = eventsPerDay[safe: 4] ?? []
        #expect(thursdayEvents.map { $0.name } == ["boundary-holiday"])
    }

    @Test func viewModel_whenHolidayTagOff_excludeHolidays() async throws {
        // given
        let holiday = Holiday(uuid: "hd", dateString: "2023-08-31", name: "boundary-holiday")
        let viewModel = self.makeViewModel(holidays: [2023: [holiday]], isHolidayOff: true)

        // when
        let eventsPerDay = try await self.settledEventsPerDay(viewModel, at: "2023-8-27-2023-9-2")

        // then
        #expect(eventsPerDay.count == 7)
        #expect(eventsPerDay.flatMap { $0 }.isEmpty)
    }

    private func settledEventsPerDay(
        _ viewModel: ContinuousMonthsViewModelImple, at weekId: String
    ) async throws -> [[any CalendarEvent]] {
        let holidayMarked = viewModel.sections
            .filter { $0[safe: 2]?.weeks.first?.days[safe: 4]?.accentDay == .holiday }
        _ = try await self.firstOutput(self.expectConfirm("공휴일이 입혀진 섹션"), for: holidayMarked)
        var latest: [[any CalendarEvent]]?
        viewModel.eventsPerDay(at: weekId)
            .sink { latest = $0 }
            .store(in: &self.cancelBag)
        try await self.waitEffect("경계 주 날짜별 이벤트 도착") { latest != nil }
        try await Task.sleep(for: .milliseconds(50))
        return latest ?? []
    }

    private func dayRange(_ year: Int, _ month: Int, _ day: Int) -> Range<TimeInterval> {
        return CalendarComponent.Day(year: year, month: month, day: day, weekDay: 1).dayRange(self.kst)!
    }
}


// MARK: - 선택·공유

extension ContinuousMonthsViewModelImpleTests {

    @Test func viewModel_whenSelectDay_updateSelectedDayIdentifier_withoutMovingFocus() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstSections(viewModel)

        // when
        let expect = self.expectConfirm("선택일 갱신")
        let identifier = try await self.firstOutput(expect, for: viewModel.selectedDayIdentifier.compactMap { $0 }) {
            viewModel.selectDay(.init(2023, 10, 3))
        }
        let focused = try await self.firstOutput(self.expectConfirm("포커스 월"), for: viewModel.focusedMonth)

        // then
        #expect(identifier == "2023-10-3")
        #expect(focused == CalendarMonth(year: 2023, month: 9))
        #expect(self.spyListener.didSelectDay == nil)
    }

    @Test func viewModel_whenUserSelectDay_notifyListener() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstSections(viewModel)
        let day = DayCellViewModel(year: 2023, month: 8, day: 31, isNotCurrentMonth: true, accentDay: nil)

        // when
        let expect = self.expectConfirm("선택일 갱신")
        let identifier = try await self.firstOutput(expect, for: viewModel.selectedDayIdentifier.compactMap { $0 }) {
            viewModel.select(day)
        }

        // then
        #expect(identifier == "2023-8-31")
        #expect(self.spyListener.didSelectDay == CalendarDay(2023, 8, 31))
    }

    @Test func viewModel_whenShareMonth_notifyRangeOfThatDaysMonth() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstSections(viewModel)
        let day = DayCellViewModel(year: 2023, month: 8, day: 31, isNotCurrentMonth: true, accentDay: nil)

        // when
        viewModel.shareEvents(.month, for: day)
        try await self.waitEffect("공유 범위 전달") { self.spyListener.didRequestShareRange != nil }

        // then
        let august = CalendarComponent(year: 2023, month: 8, weeks: []).monthRange(self.kst)
        #expect(self.spyListener.didRequestShareRange == august)
        #expect(self.spyListener.didRequestShareKind == .month)
    }
}


// MARK: - 선택일·다음날 공급

extension ContinuousMonthsViewModelImpleTests {

    @Test func continuousMonths_whenSelectDay_notifySelectedDayWithEvents() async throws {
        // given
        let events = [
            StubCalendarEvent("ev-9-12", self.dayRange(2023, 9, 12)),
            StubCalendarEvent("ev-9-13", self.dayRange(2023, 9, 13))
        ]
        let viewModel = self.makeViewModel(events: events)
        _ = try await self.firstSections(viewModel)

        // when
        viewModel.selectDay(.init(2023, 9, 12))
        let selected = try await self.waitSelectedDay { $0.0.day == 12 && !$0.1.isEmpty }

        // then
        #expect(selected.0.identifier == "2023-9-12")
        #expect(selected.0.weekId == "2023-9-10-2023-9-16")
        #expect(selected.0.range == self.dayRange(2023, 9, 12))
        #expect(selected.1 == ["ev-9-12"])
    }

    @Test func continuousMonths_whenSelectDay_notifyNextDayWithEvents() async throws {
        // given
        let events = [
            StubCalendarEvent("ev-9-12", self.dayRange(2023, 9, 12)),
            StubCalendarEvent("ev-9-13", self.dayRange(2023, 9, 13))
        ]
        let viewModel = self.makeViewModel(events: events)
        _ = try await self.firstSections(viewModel)

        // when
        viewModel.selectDay(.init(2023, 9, 12))
        let nextDay = try await self.waitNextDay { $0.0.day == 13 && !$0.1.isEmpty }

        // then
        #expect(nextDay.0.identifier == "2023-9-13")
        #expect(nextDay.0.weekId == "2023-9-10-2023-9-16")
        #expect(nextDay.0.range == self.dayRange(2023, 9, 13))
        #expect(nextDay.1 == ["ev-9-13"])
    }

    @Test func continuousMonths_whenSelectDay_notifySelectedDayWithOneNextDayAtOnce() async throws {
        // given
        let events = [
            StubCalendarEvent("ev-9-12", self.dayRange(2023, 9, 12)),
            StubCalendarEvent("ev-9-13", self.dayRange(2023, 9, 13))
        ]
        let viewModel = self.makeViewModel(events: events)
        _ = try await self.firstSections(viewModel)

        // when
        viewModel.selectDay(.init(2023, 9, 12))
        _ = try await self.waitNextDay { $0.0.day == 13 && !$0.1.isEmpty }

        // then
        let notification = try #require(self.spyListener.didChangeSelectedDayNotifications.last)
        #expect(notification.selected.0.identifier == "2023-9-12")
        #expect(notification.selected.1 == ["ev-9-12"])
        #expect(notification.nextDays.map { $0.0.identifier } == ["2023-9-13"])
    }

    @Test func continuousMonths_whenNextDayInNextWeek_notifyNextWeekEvents() async throws {
        // given
        let events = [
            StubCalendarEvent("ev-9-16", self.dayRange(2023, 9, 16)),
            StubCalendarEvent("ev-9-17", self.dayRange(2023, 9, 17))
        ]
        let viewModel = self.makeViewModel(events: events)
        _ = try await self.firstSections(viewModel)

        // when
        viewModel.selectDay(.init(2023, 9, 16))
        let nextDay = try await self.waitNextDay { $0.0.day == 17 && !$0.1.isEmpty }

        // then
        #expect(nextDay.0.identifier == "2023-9-17")
        #expect(nextDay.0.weekId == "2023-9-17-2023-9-23")
        #expect(nextDay.1 == ["ev-9-17"])
    }

    @Test func continuousMonths_whenNextDayInNextMonth_notifyNextMonthDay() async throws {
        // given
        let events = [
            StubCalendarEvent("ev-10-1", self.dayRange(2023, 10, 1))
        ]
        let viewModel = self.makeViewModel(events: events)
        _ = try await self.firstSections(viewModel)

        // when
        viewModel.selectDay(.init(2023, 9, 30))
        let nextDay = try await self.waitNextDay { $0.0.month == 10 && !$0.1.isEmpty }

        // then
        #expect(nextDay.0.identifier == "2023-10-1")
        #expect(nextDay.0.weekId == "2023-10-1-2023-10-7")
        #expect(nextDay.1 == ["ev-10-1"])
    }

    @Test func continuousMonths_whenNextDayInBoundaryWeek_notifyNextDayOfSameWeek() async throws {
        // given
        let events = [
            StubCalendarEvent("ev-8-31", self.dayRange(2023, 8, 31)),
            StubCalendarEvent("ev-9-1", self.dayRange(2023, 9, 1))
        ]
        let viewModel = self.makeViewModel(events: events)
        _ = try await self.firstSections(viewModel)

        // when
        viewModel.selectDay(.init(2023, 8, 31))
        let selected = try await self.waitSelectedDay { $0.0.day == 31 && !$0.1.isEmpty }
        let nextDay = try await self.waitNextDay { $0.0.month == 9 && !$0.1.isEmpty }

        // then
        #expect(selected.0.weekId == "2023-8-27-2023-9-2")
        #expect(selected.1 == ["ev-8-31"])
        #expect(nextDay.0.identifier == "2023-9-1")
        #expect(nextDay.0.weekId == "2023-8-27-2023-9-2")
        #expect(nextDay.1 == ["ev-9-1"])
    }

    @Test func continuousMonths_whenSelectedDayOutOfBuffer_notifyAfterBufferArrives() async throws {
        // given
        let events = [StubCalendarEvent("ev-24-3-12", self.dayRange(2024, 3, 12))]
        let viewModel = self.makeViewModel(events: events)
        _ = try await self.firstSections(viewModel)
        viewModel.selectDay(.init(2024, 3, 12))
        try await Task.sleep(for: .milliseconds(50))
        let notifiedBeforeBuffer = self.spyListener.didChangeSelectedDays.isEmpty

        // when
        viewModel.changeFocusedMonth(to: .init(year: 2024, month: 3))
        let selected = try await self.waitSelectedDay { !$0.1.isEmpty }

        // then
        #expect(notifiedBeforeBuffer)
        #expect(selected.0.identifier == "2024-3-12")
        #expect(selected.1 == ["ev-24-3-12"])
    }

    @Test func continuousMonths_whenEventsUpdated_renotifySelectedDay() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstSections(viewModel)
        viewModel.selectDay(.init(2023, 9, 12))
        _ = try await self.waitSelectedDay { $0.0.day == 12 }

        // when
        self.spyEventListUsecase.mockEvents.send([StubCalendarEvent("new-9-12", self.dayRange(2023, 9, 12))])
        let selected = try await self.waitSelectedDay { !$0.1.isEmpty }

        // then
        #expect(selected.0.identifier == "2023-9-12")
        #expect(selected.1 == ["new-9-12"])
    }

    @Test func continuousMonths_whenSelectedDayIsHoliday_includeHoliday() async throws {
        // given
        let holiday = Holiday(uuid: "hd", dateString: "2023-09-12", name: "some-holiday")
        let viewModel = self.makeViewModel(holidays: [2023: [holiday]])
        _ = try await self.firstSections(viewModel)

        // when
        viewModel.selectDay(.init(2023, 9, 12))
        let selected = try await self.waitSelectedDay { !$0.0.holidays.isEmpty && !$0.1.isEmpty }

        // then
        #expect(selected.0.holidays.map { $0.name } == ["some-holiday"])
        #expect(selected.1 == ["hd"])
    }

    @Test func continuousMonths_whenFocusShiftsKeepingSelectedDay_notNotifyAgain() async throws {
        // given
        let events = [StubCalendarEvent("ev-9-12", self.dayRange(2023, 9, 12))]
        let viewModel = self.makeViewModel(events: events)
        _ = try await self.firstSections(viewModel)
        viewModel.selectDay(.init(2023, 9, 12))
        _ = try await self.waitSelectedDay { !$0.1.isEmpty }
        _ = try await self.waitNextDay { $0.0.day == 13 }
        let countBeforeShift = self.spyListener.didChangeSelectedDays.count
        let nextDayCountBeforeShift = self.spyListener.didChangeNextDays.count

        // when
        let shifted = viewModel.sections.filter { $0.first?.month == CalendarMonth(year: 2023, month: 8) }
        _ = try await self.firstOutput(self.expectConfirm("버퍼 이동"), for: shifted) {
            viewModel.changeFocusedMonth(to: .init(year: 2023, month: 10))
        }
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.spyListener.didChangeSelectedDays.count == countBeforeShift)
        #expect(self.spyListener.didChangeNextDays.count == nextDayCountBeforeShift)
    }

    @Test func continuousMonths_whenNoSelectedDay_notNotify() async throws {
        // given
        let events = [StubCalendarEvent("ev-9-12", self.dayRange(2023, 9, 12))]
        let viewModel = self.makeViewModel(events: events)

        // when
        _ = try await self.firstSections(viewModel)
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.spyListener.didChangeSelectedDays.isEmpty)
        #expect(self.spyListener.didChangeNextDays.isEmpty)
    }

    private func waitSelectedDay(
        _ condition: @escaping ((CurrentSelectDayModel, [String])) -> Bool
    ) async throws -> (CurrentSelectDayModel, [String]) {
        try await self.waitEffect("선택일 알림") {
            self.spyListener.didChangeSelectedDays.last.map(condition) == true
        }
        return try #require(self.spyListener.didChangeSelectedDays.last)
    }

    private func waitNextDay(
        _ condition: @escaping ((CurrentSelectDayModel, [String])) -> Bool
    ) async throws -> (CurrentSelectDayModel, [String]) {
        try await self.waitEffect("다음날 알림") {
            self.spyListener.didChangeNextDays.last.map(condition) == true
        }
        return try #require(self.spyListener.didChangeNextDays.last)
    }
}


// MARK: - doubles

extension ContinuousMonthsViewModelImpleTests {

    private final class PrivateStubCalendarUsecase: StubCalendarUsecase {

        private let calendarUsecase: CalendarUsecaseImple

        init(settingUsecase: any CalendarSettingUsecase, holidayUsecase: any HolidayUsecase) {
            self.calendarUsecase = CalendarUsecaseImple(
                calendarSettingUsecase: settingUsecase, holidayUsecase: holidayUsecase
            )
            super.init(today: .init(year: 2023, month: 9, day: 10, weekDay: 1))
        }

        override func components(for month: Int, of year: Int) -> AnyPublisher<CalendarComponent, Never> {
            return self.calendarUsecase.components(for: month, of: year)
        }
    }

    private final class PrivateSpyEventListUsecase: CalendarEventListhUsecase, @unchecked Sendable {

        let mockEvents = CurrentValueSubject<[any CalendarEvent], Never>([])
        var didRequestRanges: [Range<TimeInterval>] = []

        func calendarEvents(in range: Range<TimeInterval>) -> AnyPublisher<[any CalendarEvent], Never> {
            self.didRequestRanges.append(range)
            return self.mockEvents.eraseToAnyPublisher()
        }

        func allCalendarEvents(in range: Range<TimeInterval>) -> AnyPublisher<[any CalendarEvent], Never> {
            return Empty().eraseToAnyPublisher()
        }

        func currentTodoEvents() -> AnyPublisher<[TodoCalendarEvent], Never> {
            return Empty().eraseToAnyPublisher()
        }

        func allCurrentTodoEvents() -> AnyPublisher<[TodoCalendarEvent], Never> {
            return Empty().eraseToAnyPublisher()
        }

        func uncompletedTodos() -> AnyPublisher<[TodoCalendarEvent], Never> {
            return Empty().eraseToAnyPublisher()
        }
    }

    private final class SpyListener: ContinuousMonthsSceneListener {

        var didScrollToMonth: CalendarMonth?
        func continuousMonths(didScrollTo month: CalendarMonth) {
            self.didScrollToMonth = month
        }

        var didSelectDay: CalendarDay?
        func continuousMonths(didSelect day: CalendarDay) {
            self.didSelectDay = day
        }

        var didRequestShareRange: Range<TimeInterval>?
        var didRequestShareKind: CalendarShareRangeKind?
        func continuousMonths(didRequestShare range: Range<TimeInterval>, kind: CalendarShareRangeKind) {
            self.didRequestShareRange = range
            self.didRequestShareKind = kind
        }

        var didChangeSelectedDayNotifications: [(selected: (CurrentSelectDayModel, [String]), nextDays: [(CurrentSelectDayModel, [String])])] = []
        func continuousMonths(didChangeSelectedDay day: SelectDayAndEvents, and nextDays: [SelectDayAndEvents]) {
            self.didChangeSelectedDayNotifications.append((
                (day.0, day.1.map { $0.eventId }),
                nextDays.map { ($0.0, $0.1.map { $0.eventId }) }
            ))
        }
        var didChangeSelectedDays: [(CurrentSelectDayModel, [String])] {
            return self.didChangeSelectedDayNotifications.map { $0.selected }
        }
        var didChangeNextDays: [(CurrentSelectDayModel, [String])] {
            return self.didChangeSelectedDayNotifications.compactMap { $0.nextDays.first }
        }
    }

    private struct StubCalendarEvent: CalendarEvent {
        var eventId: String
        var name: String
        var eventTime: EventTime?
        var eventTimeOnCalendar: EventTimeOnCalendar?
        var eventTagId: EventTagId = .default
        var isRepeating: Bool = false
        var isForemost: Bool = false
        var locationText: String?

        init(_ id: String, _ range: Range<TimeInterval>) {
            self.eventId = id
            self.name = id
            self.eventTime = .period(range)
            self.eventTimeOnCalendar = .init(.period(range), timeZone: TimeZone(abbreviation: "KST")!)
        }
    }
}
