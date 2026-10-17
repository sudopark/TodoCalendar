//
//  NextDayEventListViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 10/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import CalendarScenes
import CalendarPresentation


final class NextDayEventListViewModelImpleTests: PublisherWaitable, AsyncEffectWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()
    private let stubSettingUsecase = StubCalendarSettingUsecase()
    private let stubUISettingUsecase = StubUISettingUsecase()
    private let kst = TimeZone(abbreviation: "KST")!

    private func makeViewModel(
        liveActivityTarget: LiveActivityTarget? = nil,
        ddayCandidates: [DDayCandidate] = []
    ) -> NextDayEventListViewModelImple {
        self.stubSettingUsecase.prepare()
        _ = self.stubUISettingUsecase.loadSavedAppearanceSetting()
        return NextDayEventListViewModelImple(
            calendarSettingUsecase: self.stubSettingUsecase,
            uiSettingUsecase: self.stubUISettingUsecase,
            foremostEventUsecase: StubForemostEventUsecase(),
            eventLiveActivityUsecase: StubEventLiveActivityUsecase(registeredTarget: liveActivityTarget),
            ddayCandidateUsecase: StubDDayCandidateUsecase(ddayCandidates)
        )
    }

    private func time(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> TimeInterval {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.kst
        let components = DateComponents(year: year, month: month, day: day, hour: hour)
        return calendar.date(from: components)!.timeIntervalSince1970
    }

    private func nextDay(
        _ year: Int, _ month: Int, _ day: Int, holidays: [Holiday] = []
    ) -> CurrentSelectDayModel {
        let range = self.time(year, month, day, 0)..<self.time(year, month, day + 1, 0) - 1
        return CurrentSelectDayModel(year, month, day, weekId: "week", range: range)
            |> \.holidays .~ holidays
    }

    private func schedule(
        _ id: String, _ eventTime: EventTime, isForemost: Bool = false
    ) -> ScheduleCalendarEvent {
        return ScheduleCalendarEvent(
            eventIdWithoutTurn: id,
            eventId: id,
            name: id,
            eventTime: eventTime,
            eventTimeOnCalendar: .init(eventTime, timeZone: self.kst),
            eventTagId: .default,
            isRepeating: false,
            isForemost: isForemost
        )
    }

    private func dateText(_ time: TimeInterval, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter() |> \.timeZone .~ timeZone
        formatter.dateFormat = "date_form::yyyy_MM_dd_E_".localized()
        return formatter.string(from: Date(timeIntervalSince1970: time))
    }

    private func firstCellIds(
        _ viewModel: NextDayEventListViewModelImple,
        nextDay: CurrentSelectDayModel,
        events: [any CalendarEvent]
    ) async throws -> [String]? {
        let expect = self.expectConfirm("다음날 셀 방출")
        let cells = try await self.firstOutput(expect, for: viewModel.cellViewModels) {
            viewModel.nextDayChanged(nextDay, and: events)
        }
        return cells?.map { $0.eventIdentifier }
    }
}


// MARK: - 다음날 헤더

extension NextDayEventListViewModelImpleTests {

    @Test func viewModel_whenNextDayChanged_provideDayModelWithHoliday() async throws {
        // given
        let expect = self.expectConfirm("다음날 헤더 방출")
        let viewModel = self.makeViewModel()
        let holiday = Holiday(uuid: "h-0911", dateString: "2023-09-11", name: "next day holiday")

        // when
        let model = try await self.firstOutput(expect, for: viewModel.dayModel) {
            viewModel.nextDayChanged(self.nextDay(2023, 9, 11, holidays: [holiday]), and: [])
        }

        // then
        #expect(model?.dateText == self.dateText(self.time(2023, 9, 11, 0), in: self.kst))
        #expect(model?.holidayName == "next day holiday")
    }

    @Test func viewModel_whenTimeZoneChanged_recomputeDayModel() async throws {
        // given
        let utc = TimeZone(identifier: "UTC")!
        let viewModel = self.makeViewModel()
        var models: [SelectedDayModel] = []
        viewModel.dayModel
            .sink { models.append($0) }
            .store(in: &self.cancelBag)

        // when
        viewModel.nextDayChanged(self.nextDay(2023, 9, 11), and: [])
        try await self.waitEffect("KST 헤더 방출") { models.count == 1 }
        self.stubSettingUsecase.selectTimeZone(utc)
        try await self.waitEffect("UTC 헤더 방출") { models.count == 2 }
        try await Task.sleep(for: .milliseconds(50))

        // then
        let dayStart = self.time(2023, 9, 11, 0)
        #expect(models.map { $0.dateText } == [
            self.dateText(dayStart, in: self.kst), self.dateText(dayStart, in: utc)
        ])
    }

    @Test func viewModel_beforeNextDayChanged_provideNothing() async throws {
        // given
        let viewModel = self.makeViewModel()
        var dayModels: [SelectedDayModel] = []
        var cells: [[any EventCellViewModel]] = []
        viewModel.dayModel.sink { dayModels.append($0) }.store(in: &self.cancelBag)
        viewModel.cellViewModels.sink { cells.append($0) }.store(in: &self.cancelBag)

        // when
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(dayModels.isEmpty)
        #expect(cells.isEmpty)
    }
}


// MARK: - 다음날 셀

extension NextDayEventListViewModelImpleTests {

    @Test func viewModel_provideCellsOfGivenEventsIncludingHoliday() async throws {
        // given
        let viewModel = self.makeViewModel()
        let holiday = Holiday(uuid: "h-0911", dateString: "2023-09-11", name: "next day holiday")
        let holidayEvent = try #require(HolidayCalendarEvent(holiday, in: self.kst))

        // when
        let ids = try await self.firstCellIds(
            viewModel,
            nextDay: self.nextDay(2023, 9, 11, holidays: [holiday]),
            events: [self.schedule("meeting", .at(self.time(2023, 9, 11, 12))), holidayEvent]
        )

        // then
        #expect(ids == ["h-0911", "meeting"])
    }

    @Test func viewModel_excludeForemostEvent() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        let ids = try await self.firstCellIds(viewModel, nextDay: self.nextDay(2023, 9, 11), events: [
            self.schedule("foremost", .at(self.time(2023, 9, 11, 9)), isForemost: true),
            self.schedule("normal", .at(self.time(2023, 9, 11, 12)))
        ])

        // then
        #expect(ids == ["normal"])
    }

    @Test func viewModel_sortCellsByEventTime() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        let ids = try await self.firstCellIds(viewModel, nextDay: self.nextDay(2023, 9, 11), events: [
            self.schedule("afternoon", .at(self.time(2023, 9, 11, 15))),
            self.schedule("morning", .at(self.time(2023, 9, 11, 9)))
        ])

        // then
        #expect(ids == ["morning", "afternoon"])
    }

    @Test func viewModel_applyLiveActivityAndDDayRegistration() async throws {
        // given
        let expect = self.expectConfirm("등록 반영된 셀 방출")
        let viewModel = self.makeViewModel(
            liveActivityTarget: .schedule(id: "live", turnKey: nil),
            ddayCandidates: [.init(scheduleId: "dday")]
        )
        let events: [any CalendarEvent] = [
            self.schedule("live", .at(self.time(2023, 9, 11, 9))),
            self.schedule("dday", .at(self.time(2023, 9, 11, 12)))
        ]

        // when
        let cells = try await self.firstOutput(expect, for: viewModel.cellViewModels) {
            viewModel.nextDayChanged(self.nextDay(2023, 9, 11), and: events)
        }

        // then
        let schedules = cells?.compactMap { $0 as? ScheduleEventCellViewModel }
        #expect(schedules?.map { $0.isLiveActivityRegistered } == [true, false])
        #expect(schedules?.map { $0.isDDayCandidateRegistered } == [false, true])
    }

    @Test func viewModel_whenNoEventsOnNextDay_provideEmptyCells() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        let ids = try await self.firstCellIds(viewModel, nextDay: self.nextDay(2023, 9, 11), events: [])

        // then
        #expect(ids == [])
    }

    @Test func viewModel_whenNextDayChangedAgain_provideLatestNextDayOnly() async throws {
        // given
        let viewModel = self.makeViewModel()
        var cells: [[String]] = []
        viewModel.cellViewModels
            .sink { cells.append($0.map { $0.eventIdentifier }) }
            .store(in: &self.cancelBag)

        // when
        viewModel.nextDayChanged(
            self.nextDay(2023, 9, 11), and: [self.schedule("sep-11", .at(self.time(2023, 9, 11, 12)))]
        )
        try await self.waitEffect("9월 11일 셀 방출") { cells.count == 1 }
        viewModel.nextDayChanged(
            self.nextDay(2023, 9, 21), and: [self.schedule("sep-21", .at(self.time(2023, 9, 21, 12)))]
        )
        try await self.waitEffect("9월 21일 셀 방출") { cells.count == 2 }
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(cells == [["sep-11"], ["sep-21"]])
    }
}
