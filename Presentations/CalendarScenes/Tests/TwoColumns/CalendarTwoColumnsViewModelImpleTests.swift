//
//  CalendarTwoColumnsViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Combine
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import CalendarScenes
import CalendarPresentation


final class CalendarTwoColumnsViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()
    private let spyContinuousMonths = SpyContinuousMonthsInteractor()
    private let spyEventList = SpyEventListInteractor()
    private let spyNextDay = SpyNextDayInteractor()
    private let spyListener = SpyListener()
    private let spyRouter = SpyRouter()

    private func makeViewModel() -> CalendarTwoColumnsViewModelImple {
        let viewModel = CalendarTwoColumnsViewModelImple(
            continuousMonthsInteractor: self.spyContinuousMonths,
            eventListInteractor: self.spyEventList,
            nextDayInteractor: self.spyNextDay
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListener
        return viewModel
    }

    private func dayModel(_ day: Int) -> CurrentSelectDayModel {
        return .init(2023, 9, day, weekId: "2023-9-10-2023-9-16", range: Double(day)..<Double(day + 1))
    }
}


// MARK: - 상위 입력을 부품에 넘김

extension CalendarTwoColumnsViewModelImpleTests {

    @Test func twoColumns_whenChangeFocusedMonth_forwardToContinuousMonths() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.changeFocusedMonth(to: .init(year: 2023, month: 10))

        // then
        #expect(self.spyContinuousMonths.didChangeFocusedMonths == [.init(year: 2023, month: 10)])
    }

    @Test func twoColumns_whenSelectDay_forwardToContinuousMonths() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.selectDay(.init(2023, 9, 12))

        // then
        #expect(self.spyContinuousMonths.didSelectDays == [CalendarDay(2023, 9, 12)])
    }

    @Test("선택일이 오늘인지를 일별 목록에 넘긴다", arguments: [true, false])
    func twoColumns_whenSelectedDayIsToday_forwardToEventList(_ isToday: Bool) {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.selectedDayIsToday(isToday)

        // then
        #expect(self.spyEventList.didSelectedDayIsToday == isToday)
    }

    @Test func twoColumns_whenScrollToVoiceInput_requestScroll() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        let request: Void? = try await self.firstOutput(
            self.expectConfirm("음성 입력 스크롤 요청"), for: viewModel.requestScrollToVoiceInput
        ) {
            viewModel.scrollToVoiceInput()
        }

        // then
        #expect(request != nil)
    }
}


// MARK: - 부품 출력을 공급·중계

extension CalendarTwoColumnsViewModelImpleTests {

    @Test func twoColumns_whenContinuousMonthsScrolled_notifyListener() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.continuousMonths(didScrollTo: .init(year: 2023, month: 11))

        // then
        #expect(self.spyListener.didScrollToMonth == CalendarMonth(year: 2023, month: 11))
    }

    @Test func twoColumns_whenContinuousMonthsSelect_notifyListener() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.continuousMonths(didSelect: .init(2023, 9, 20))

        // then
        #expect(self.spyListener.didSelectDay == CalendarDay(2023, 9, 20))
    }

    @Test func twoColumns_whenSelectedDayChanged_supplyEventListAndNextDay() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.continuousMonths(
            didChangeSelectedDay: (self.dayModel(12), [StubEvent("ev-12")]),
            and: [(self.dayModel(13), [StubEvent("ev-13")])]
        )

        // then
        #expect(self.spyEventList.selectedDays == [self.dayModel(12)])
        #expect(self.spyEventList.selectedDayEventIds == [["ev-12"]])
        #expect(self.spyNextDay.nextDays == [self.dayModel(13)])
        #expect(self.spyNextDay.nextDayEventIds == [["ev-13"]])
    }

    @Test func twoColumns_whenSelectedDayChangedWithoutNextDay_supplyOnlyEventList() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.continuousMonths(
            didChangeSelectedDay: (self.dayModel(12), [StubEvent("ev-12")]), and: []
        )

        // then
        #expect(self.spyEventList.selectedDays == [self.dayModel(12)])
        #expect(self.spyNextDay.nextDays.isEmpty)
    }

    @Test func twoColumns_whenShareRequested_routeToSharePreview() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.continuousMonths(didRequestShare: 10..<20, kind: .week)

        // then
        #expect(self.spyRouter.didShowSharePreviewWithRange == 10..<20)
        #expect(self.spyRouter.didShowSharePreviewWithKind == .week)
    }

    @Test func twoColumns_whenEventListRequestAI_notifyListener() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.dayEventListDidRequestShowAICommand()

        // then
        #expect(self.spyListener.didRequestShowAICommand == true)
        #expect(self.spyListener.didRequestReturnToToday == nil)
    }

    @Test func twoColumns_whenEventListRequestToday_notifyListener() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.dayEventListDidRequestReturnToToday()

        // then
        #expect(self.spyListener.didRequestReturnToToday == true)
        #expect(self.spyListener.didRequestShowAICommand == nil)
    }
}


// MARK: - doubles

extension CalendarTwoColumnsViewModelImpleTests {

    private final class SpyContinuousMonthsInteractor: ContinuousMonthsSceneInteractor {

        var didChangeFocusedMonths: [CalendarMonth] = []
        func changeFocusedMonth(to month: CalendarMonth) {
            self.didChangeFocusedMonths.append(month)
        }

        var didSelectDays: [CalendarDay] = []
        func selectDay(_ day: CalendarDay) {
            self.didSelectDays.append(day)
        }
    }

    private final class SpyEventListInteractor: DayEventListSceneInteractor {

        var selectedDays: [CurrentSelectDayModel] = []
        var selectedDayEventIds: [[String]] = []
        func selectedDayChanaged(_ newDay: CurrentSelectDayModel, and eventThatDay: [any CalendarEvent]) {
            self.selectedDays.append(newDay)
            self.selectedDayEventIds.append(eventThatDay.map { $0.eventId })
        }

        var didSelectedDayIsToday: Bool?
        func selectedDayIsToday(_ isToday: Bool) {
            self.didSelectedDayIsToday = isToday
        }
    }

    private final class SpyNextDayInteractor: NextDayEventListSceneInteractor {

        var nextDays: [CurrentSelectDayModel] = []
        var nextDayEventIds: [[String]] = []
        func nextDayChanged(_ nextDay: CurrentSelectDayModel, and eventsThatDay: [any CalendarEvent]) {
            self.nextDays.append(nextDay)
            self.nextDayEventIds.append(eventsThatDay.map { $0.eventId })
        }
    }

    private final class SpyListener: CalendarTwoColumnsSceneListener {

        var didScrollToMonth: CalendarMonth?
        func calendarTwoColumns(didScrollTo month: CalendarMonth) {
            self.didScrollToMonth = month
        }

        var didSelectDay: CalendarDay?
        func calendarTwoColumns(didSelect day: CalendarDay) {
            self.didSelectDay = day
        }

        var didRequestShowAICommand: Bool?
        func calendarTwoColumnsDidRequestShowAICommand() {
            self.didRequestShowAICommand = true
        }

        var didRequestReturnToToday: Bool?
        func calendarTwoColumnsDidRequestReturnToToday() {
            self.didRequestReturnToToday = true
        }
    }

    private final class SpyRouter: BaseSpyRouter, CalendarTwoColumnsRouting, @unchecked Sendable {

        var didShowSharePreviewWithRange: Range<TimeInterval>?
        var didShowSharePreviewWithKind: CalendarShareRangeKind?
        func showSharePreview(range: Range<TimeInterval>, kind: CalendarShareRangeKind) {
            self.didShowSharePreviewWithRange = range
            self.didShowSharePreviewWithKind = kind
        }
    }

    private struct StubEvent: CalendarEvent {
        var eventId: String
        var name: String
        var eventTime: EventTime?
        var eventTimeOnCalendar: EventTimeOnCalendar?
        var eventTagId: EventTagId = .default
        var isRepeating: Bool = false
        var isForemost: Bool = false
        var locationText: String?

        init(_ id: String) {
            self.eventId = id
            self.name = id
        }
    }
}
