//
//  MonthViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 2023/07/05.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import CalendarScenes


class MonthViewModelImpleTests: BaseTestCase, PublisherWaitable {

    var cancelBag: Set<AnyCancellable>!
    private var stubSettingUsecase: StubCalendarSettingUsecase!
    private var stubTodoUsecase: PrivateStubTodoUsecase!
    private var stubScheduleUsecase: PrivateStubScheduleUsecase!
    private var stubTagUsecase: StubEventTagUsecase!
    private var stubUISettingUsecase: StubUISettingUsecase!
    private var spyListener: SpyListener?
    
    private var timeoutMillis: Int { return 10 }

    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubSettingUsecase = .init()
        self.stubTodoUsecase = .init()
        self.stubScheduleUsecase = .init()
        self.stubTagUsecase = .init()
        self.stubUISettingUsecase = .init()
        self.spyListener = .init()
    }

    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubSettingUsecase = nil
        self.stubTodoUsecase = nil
        self.stubScheduleUsecase = nil
        self.stubTagUsecase = nil
        self.stubUISettingUsecase = nil
        self.spyListener = nil
    }

    private func makeViewModel() -> MonthViewModelImple {
        let calendarUsecase = PrivateStubCalendarUsecase(
            today: .init(year: 2023, month: 09, day: 10, weekDay: 1)
        )
        self.stubSettingUsecase.prepare()
        
        _ = self.stubUISettingUsecase.loadSavedAppearanceSetting()

        let viewModel = MonthViewModelImple(
            initialMonth: .init(year: 2023, month: 9),
            calendarUsecase: calendarUsecase,
            calendarSettingUsecase: self.stubSettingUsecase,
            todoUsecase: self.stubTodoUsecase,
            scheduleEventUsecase: self.stubScheduleUsecase,
            eventTagUsecase: self.stubTagUsecase,
            uiSettingUsecase: self.stubUISettingUsecase
        )
        viewModel.attachListener(self.spyListener!)
        return viewModel
    }
}


// MARK: - provide components

extension MonthViewModelImpleTests {

    func testViewModel_whenUpdateMonth_provideCalendarWeeks() {
        // given
        let expect = expectation(description: "지정된 달의 날짜 반환")
        let viewModel = self.makeViewModel()

        // when
        let weeks = self.waitFirstOutput(expect, for: viewModel.weekModels) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 9))
        } ?? []

        // then
        XCTAssertEqual(
            weeks.map { ws in ws.days.map { $0.day } },
            CalendarComponent.dummy2023_9().weeks.map { ws in ws.days.map { $0.day } }
        )
        XCTAssertEqual(weeks.map { ws in ws.days.map { $0.isNotCurrentMonth }}, [
            [true, true, true, true, true, false, false],
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7)
        ])
    }

    func testViewModel_whenMonthUpdated_updateCalendarWeeks() {
        // given
        let expect = expectation(description: "지장된 달 변경")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()

        // when
        let weekLists = self.waitOutputs(expect, for: viewModel.weekModels) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 9))
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 9))    // ignore
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 8))
        }

        // then
        let weeksFor9 = weekLists.first ?? []
        let weeksFor8 = weekLists.last ?? []
        XCTAssertEqual(
            weeksFor9.map { ws in ws.days.map { $0.day } },
            CalendarComponent.dummy2023_9().weeks.map { ws in ws.days.map { $0.day } }
        )
        XCTAssertEqual(weeksFor9.map { ws in ws.days.map { $0.isNotCurrentMonth }}, [
            [true, true, true, true, true, false, false],
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7)
        ])

        XCTAssertEqual(
            weeksFor8.map { ws in ws.days.map { $0.day } },
            CalendarComponent.dummy2023_8().weeks.map { ws in ws.days.map { $0.day } }
        )
        XCTAssertEqual(weeksFor8.map { ws in ws.days.map { $0.isNotCurrentMonth }}, [
            [true, true, false, false, false, false, false],
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7),
            Array(repeating: false, count: 7),
            [false, false, false, false, false, true, true]
        ])
    }
}


// MARK: - selected day

extension MonthViewModelImpleTests {

    func testViewModel_whenCurrentMonthIsEqualTodayMonth_defaultSelectionDayIsToday() {
        // given
        let expect = expectation(description: "지정된 달이 오늘과 같은 달이면 최초 선택값은 오늘")
        let viewModel = self.makeViewModel()

        // when
        let selected = self.waitFirstOutput(expect, for: viewModel.currentSelectDayIdentifier) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 9))
        } ?? nil

        // then
        XCTAssertEqual(selected, "2023-9-10")
    }

    func testViewModel_whenCurrentMonthIsNotEqualTodayMonth_defaultSelectionDayIsMonthFirstDay() {
        // given
        let expect = expectation(description: "지정된 달이 오늘과 같은 달이 아니면 1일 디폴트로 선택")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()

        // when
        let selecteds = self.waitOutputs(expect, for: viewModel.currentSelectDayIdentifier) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 9))
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 8))
        }

        // then
        XCTAssertEqual(selecteds, [
            "2023-9-10", "2023-8-1"
        ])
    }

    func testViewModel_whenSelectDay_updateSelectedDay() {
        // given
        let expect = expectation(description: "날짜 선택시에 해당 날짜가 선택한 날짜가 됨")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()

        // when
        let selecteds = self.waitOutputs(expect, for: viewModel.currentSelectDayIdentifier) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 09))
            viewModel.select(
                .init(
                    year: 2023, month: 9, day: 23, isNotCurrentMonth: false,
                    accentDay: nil
                )
            )
        }

        // then
        XCTAssertEqual(selecteds, [
            "2023-9-10", "2023-9-23"
        ])
    }

    func testViewModel_whenSelectNotThisMonth_updateSelectedDay() {
        // given
        let expect = expectation(description: "9월 달력에서 8월 말일 선택(ok) -> 9월 20일 선택 -> 이후 8월로 변경시 8월 1일로 선택값 변경 -> 다시 9월로 전환시 9월10(today)일로 선택값 변경")
        expect.expectedFulfillmentCount = 5
        let viewModel = self.makeViewModel()

        // when
        let selecteds = self.waitOutputs(expect, for: viewModel.currentSelectDayIdentifier, timeout: 0.01) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 09))
            viewModel.select(
                .init(
                    year: 2023, month: 08, day: 31, isNotCurrentMonth: true,
                    accentDay: nil
                )
            )
            viewModel.select(
                .init(
                    year: 2023, month: 9, day: 20, isNotCurrentMonth: true,
                    accentDay: nil
                )
            )
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 08))
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 09))
        }

        // then
        XCTAssertEqual(selecteds, [
            "2023-9-10", "2023-8-31", "2023-9-20", "2023-8-1", "2023-9-10"
        ])
    }

    func testViewModel_provideToday() {
        // given
        let expect = expectation(description: "오늘 날짜정보 제공")
        let viewModel = self.makeViewModel()

        // when
        let today = self.waitFirstOutput(expect, for: viewModel.todayIdentifier)

        // then
        XCTAssertEqual(today, "2023-9-10")
    }
}

// MARK: - test events

extension MonthViewModelImpleTests {
    
    private func dummyEventLine(_ days: ClosedRange<Int>) -> WeekEventLineModel {
        let dayIdentifiers = days.map { "2023-9-\($0)" }
        let todo = TodoCalendarEvent(.init(uuid: "\(days)", name: "todo:\(days)"), in: TimeZone.current)
        let event = EventOnWeek(0..<1, [], days, dayIdentifiers, todo)
        return .init(event, nil)
    }

    func testEventStackModel_provideEventMoreCounts() {
        // given
        let lines: [[WeekEventLineModel]] = [
            [self.dummyEventLine(1...5)],
            [self.dummyEventLine(2...4)],
            [self.dummyEventLine(1...3), self.dummyEventLine(4...7)],
            [self.dummyEventLine(1...4)],
            [self.dummyEventLine(1...6)]
        ]
        let stack = WeekEventStackViewModel(linesStack: lines, shouldMarkEventDays: false)
        
        // when
        let moreModels = stack.eventMores(with: 3).sorted(by: { $0.daySequence < $1.daySequence })
        
        // then
        XCTAssertEqual(moreModels, [
            .init(daySequence: 1, dayIdentifier: "2023-9-1", moreCount: 2),
            .init(daySequence: 2, dayIdentifier: "2023-9-2", moreCount: 2),
            .init(daySequence: 3, dayIdentifier: "2023-9-3", moreCount: 2),
            .init(daySequence: 4, dayIdentifier: "2023-9-4", moreCount: 2),
            .init(daySequence: 5, dayIdentifier: "2023-9-5", moreCount: 1),
            .init(daySequence: 6, dayIdentifier: "2023-9-6", moreCount: 1)
        ])
    }

    private func makeViewModelWithStubEvents() -> MonthViewModelImple {
        let todo_w2_sun_wed = TodoEvent(uuid: "todo_w2_sun_wed", name: "some")
            |> \.time .~ .dummyPeriod(from: (09, 10), to: (09, 13))
        let todo_w1_mon = TodoEvent(uuid: "todo_w1_mon", name: "some")
            |> \.time .~ .dummyAt(08, 28)
        let pdtTimeZone = TimeZone(abbreviation: "PDT")!
        let range = try! TimeInterval.range(
            from: "2023-08-29 00:00:00", to: "2023-08-29 23:59:59", in: pdtTimeZone
        )
        let offset = TimeInterval(pdtTimeZone.secondsFromGMT(for: Date(timeIntervalSince1970: range.lowerBound)))
        let todo8_29_allday = TodoEvent(uuid: "todo8_29_allday", name: "allday")
            |> \.time .~ .allDay(range, secondsFromGMT: offset)
        self.stubTodoUsecase.eventsFor9 = [todo_w2_sun_wed, todo_w1_mon, todo8_29_allday]

        let schedule_w2_tue_fri = ScheduleEvent(
            uuid: "schedule_w2_tue_fri", name: "some",
            time: .dummyPeriod(from: (09, 12), to: (09, 15))
        )
        let schedule_event_repeating = ScheduleEvent(
            uuid: "schedule_event_repeating", name: "some",
            time: EventTime.dummyPeriod(from: (07, 20), to: (07, 30))
        )
        |> \.repeating .~ EventRepeating(repeatingStartTime: 0, repeatOption: EventRepeatingOptions.EveryDay())
        |> \.nextRepeatingTimes .~ [
            .init(time: EventTime.dummyPeriod(from: (07, 31), to: (08, 16)), turn: 2),
            .init(time: EventTime.dummyPeriod(from: (08, 25), to: (08, 29)), turn: 3),
            .init(time: EventTime.dummyPeriod(from: (09, 14), to: (09, 16)), turn: 4),
            .init(time: EventTime.dummyPeriod(from: (09, 19), to: (09, 26)), turn: 5),
            .init(time: EventTime.dummyPeriod(from: (09, 26), to: (09, 28)), turn: 6),
            .init(time: EventTime.dummyAt(10, 1), turn: 7)
        ]
        self.stubScheduleUsecase.eventsFor9 = [schedule_w2_tue_fri, schedule_event_repeating]

        let singleEventOn8 = TodoEvent(uuid: "todo8", name: "some")
            |> \.time .~ .dummyAt(08, 13)
            |> \.eventTagId .~ .custom("some")
        self.stubTodoUsecase.eventsFor8 = [singleEventOn8, todo_w1_mon, todo8_29_allday]
        self.stubScheduleUsecase.eventsFor8 = [
            schedule_event_repeating
        ]
        
        
        return self.makeViewModel()
    }

    private func removeTodo0828() {
        self.stubTodoUsecase.eventsFor9 = self.stubTodoUsecase.eventsFor9.filter { $0.uuid != "todo_w1_mon" }
    }

    private func changeToPDTTimeZone() {
        self.stubSettingUsecase.selectTimeZone(TimeZone(abbreviation: "PDT")!)
    }

    private func waitAndAssertWeeksFor9Eventes(
        _ viewModel: MonthViewModelImple
    ) async throws {
        
        async let weekSource = viewModel.weekModels.firstValue(with: self.timeoutMillis)
        viewModel.updateMonthIfNeed(.init(year: 2023, month: 09))
        
        let weeks = try await weekSource
        XCTAssertEqual(weeks?.count, 5)
        
        // assert week1
        let week1 = weeks?[safe: 0]
        let week1Events = try await viewModel.eventStack(at: week1?.id ?? "")
            .firstValue(with: self.timeoutMillis) ?? .init(linesStack: [], shouldMarkEventDays: false)
        let week1EventIds = week1Events.eventIds
        let week1EventDaysSequences = week1Events.daysSequences
            
        XCTAssertEqual(week1EventIds, [
            ["schedule_event_repeating-3"],
            ["todo_w1_mon", "todo8_29_allday"]
        ])
        XCTAssertEqual(week1EventDaysSequences, [
            [(1...3)],
            [(2...2), (3...3)]
        ])

        // assert week2
        let week2 = weeks?[safe: 1]
        let week2Events = try await viewModel.eventStack(at: week2?.id ?? "")
            .firstValue(with: self.timeoutMillis) ?? .init(linesStack: [], shouldMarkEventDays: false)
        let week2EventIds = week2Events.eventIds
        XCTAssertEqual(week2EventIds, [])
        

        // assert week3
        let week3 = weeks?[safe: 2]
        let week3Events = try await viewModel.eventStack(at: week3?.id ?? "")
            .firstValue(with: self.timeoutMillis) ?? .init(linesStack: [], shouldMarkEventDays: false)
        let week3EventIds = week3Events.eventIds
        let week3EventDaysSequences = week3Events.daysSequences
        XCTAssertEqual(week3EventIds, [
            ["todo_w2_sun_wed", "schedule_event_repeating-4"],
            ["schedule_w2_tue_fri-1"]
        ])
        XCTAssertEqual(week3EventDaysSequences, [
            [(1...4), (5...7)],
            [(3...6)]
        ])

        // assert week4
        let week4 = weeks?[safe: 3]
        let week4Events = try await viewModel.eventStack(at: week4?.id ?? "")
            .firstValue(with: self.timeoutMillis) ?? .init(linesStack: [], shouldMarkEventDays: false)
        let week4EventIds = week4Events.eventIds
        let week4EventDaysSequences = week4Events.daysSequences
        XCTAssertEqual(week4EventIds, [
            ["schedule_event_repeating-5"]
        ])
        XCTAssertEqual(week4EventDaysSequences, [
            [(3...7)]
        ])

        // assert week5
        let week5 = weeks?[safe: 4]
        let week5Events = try await viewModel.eventStack(at: week5?.id ?? "")
            .firstValue(with: self.timeoutMillis) ?? .init(linesStack: [], shouldMarkEventDays: false)
        let week5EventIds = week5Events.eventIds
        let week5EventDaysSequences = week5Events.daysSequences
        XCTAssertEqual(week5EventIds, [
            ["schedule_event_repeating-5", "2023-09-28-추석", "2023-09-29-추석", "2023-09-30-추석"],
            ["schedule_event_repeating-6"]
        ])
        XCTAssertEqual(week5EventDaysSequences, [
            [(1...3), (5...5), (6...6), (7...7)],
            [(3...5)]
        ])
    }

    private func waitAndAssertWeeksFor8(
        _ viewModel: MonthViewModelImple,
        shouldDropFirst: Bool = true
    ) async throws {
        
        let dropCount = shouldDropFirst ? 1 : 0
        async let weekSource =  viewModel.weekModels.dropFirst(dropCount).firstValue(with: self.timeoutMillis)
        viewModel.updateMonthIfNeed(.init(year: 2023, month: 08))
        let weeks = try await weekSource
        
        XCTAssertEqual(weeks?.count, 5)
        
        // assert week1
        let week1 = weeks?[safe: 0]
        let week1Events = try await viewModel.eventStack(at: week1?.id ?? "")
            .firstValue(with: self.timeoutMillis)
        XCTAssertEqual(week1Events?.eventIds, [
            ["schedule_event_repeating-1", "schedule_event_repeating-2"]
        ])
        XCTAssertEqual(week1Events?.daysSequences, [
            [(1...1), (2...7)]
        ])
        
        // assert week2
        let week2 = weeks?[safe: 1]
        let week2Events = try await viewModel.eventStack(at: week2?.id ?? "")
            .firstValue(with: self.timeoutMillis)
        XCTAssertEqual(week2Events?.eventIds, [
            ["schedule_event_repeating-2"]
        ])
        XCTAssertEqual(week2Events?.daysSequences, [
            [(1...7)]
        ])
       
        // assert week3
        let week3 = weeks?[safe: 2]
        let week3Events = try await viewModel.eventStack(at: week3?.id ?? "")
            .firstValue(with: self.timeoutMillis)
        XCTAssertEqual(week3Events?.eventIds, [
            ["schedule_event_repeating-2"],
            ["todo8", "2023-08-15-광복절"]
        ])
        XCTAssertEqual(week3Events?.daysSequences, [
            [(1...4)],
            [(1...1), (3...3)]
        ])
       
        // assert week4
        let week4 = weeks?[safe: 3]
        let week4Events = try await viewModel.eventStack(at: week4?.id ?? "")
            .firstValue(with: self.timeoutMillis)
        XCTAssertEqual(week4Events?.eventIds, [
            ["schedule_event_repeating-3"]
        ])
        XCTAssertEqual(week4Events?.daysSequences, [
            [(6...7)]
        ])
       
        // assert week5
        let week5 = weeks?[safe: 4]
        let week5Events = try await viewModel.eventStack(at: week5?.id ?? "")
            .firstValue(with: self.timeoutMillis)
        XCTAssertEqual(week5Events?.eventIds, [
            ["schedule_event_repeating-3"],
            ["todo_w1_mon", "todo8_29_allday"]
        ])
        XCTAssertEqual(week5Events?.daysSequences, [
            [(1...3)],
            [(2...2), (3...3)]
        ])
    }

    func testViewModel_whenFirstWeekDayChanges_updateWeekDaysSymbol() {
        // given
        let expect = expectation(description: "주 시작일 변경시에 요일 심볼리스트도 변경")
        expect.expectedFulfillmentCount = 8
        let viewModel = self.makeViewModel()

        // when
        let modelLists = self.waitOutputs(expect, for: viewModel.weekDays) {
            let days: [DayOfWeeks] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
            days.forEach {
                self.stubSettingUsecase.updateFirstWeekDay($0)
            }
        }

        // then
        let weekDayLists = modelLists.map { ms in ms.map { $0.symbol } }
        XCTAssertEqual(weekDayLists, [
            ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"],
            ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"],
            ["TUE", "WED", "THU", "FRI", "SAT", "SUN", "MON"],
            ["WED", "THU", "FRI", "SAT", "SUN", "MON", "TUE"],
            ["THU", "FRI", "SAT", "SUN", "MON", "TUE", "WED"],
            ["FRI", "SAT", "SUN", "MON", "TUE", "WED", "THU"],
            ["SAT", "SUN", "MON", "TUE", "WED", "THU", "FRI"],
            ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        ])
        let isWeekEnds = modelLists.map { ms in ms.map { $0.isSaturday || $0.isSunday } }
        XCTAssertEqual(isWeekEnds, [
            [true, false, false, false, false, false, true],
            [false, false, false, false, false, true, true],
            [false, false, false, false, true, true, false],
            [false, false, false, true, true, false, false],
            [false, false, true, true, false, false, false],
            [false, true, true, false, false, false, false],
            [true, true, false, false, false, false, false],
            [true, false, false, false, false, false, true],
        ])
    }

    // 이벤트 정보와 함께 달력 정보 제공 + 이때 해당되는 일정의 todo만, 해당 월에서 반복시간이 없는 스케쥴이나, 반복시간이 해당 월에 매칭되는 경우만 반환
    func testViewModel_provideWeekModelsWithEvent() async throws {
        // given
        let viewModel = self.makeViewModelWithStubEvents()

        // when + then
        try await self.waitAndAssertWeeksFor9Eventes(viewModel)
    }

    // 달 변경시에 변경된 이벤트 방출
    func testViewModel_whenAfterChangeMonth_updateWeekModelWithEvents() async throws {
        // given
        let viewModel = self.makeViewModelWithStubEvents()

        // when + then
        try await self.waitAndAssertWeeksFor9Eventes(viewModel)
        try await self.waitAndAssertWeeksFor8(viewModel, shouldDropFirst: true)
    }

    func testViewModel_whenEventStackChangesOnMonth_updateWeekModels() async throws {
        // given
        let viewModel = self.makeViewModelWithStubEvents()

        
        try await self.waitAndAssertWeeksFor9Eventes(viewModel)
        
        async let weeks = viewModel.weekModels.firstValue(with: self.timeoutMillis)
        self.removeTodo0828()
        let updatedFirstWeek = try await weeks?.first
        let updatedFirstWeekEvents = try await viewModel.eventStack(at: updatedFirstWeek?.id ?? "")
            .firstValue(with: self.timeoutMillis)

        // then
        XCTAssertEqual(updatedFirstWeekEvents?.eventIds, [
            ["schedule_event_repeating-3"],
            ["todo8_29_allday"]
        ])
        XCTAssertEqual(updatedFirstWeekEvents?.daysSequences, [
            [(1...3)],
            [(3...3)]
        ])
    }

    func testViewModel_whenTimeZoneChanges_updateWeekModelWithNewEventRange() async throws {
        // given
        let viewModel = self.makeViewModelWithStubEvents()

        // when
        try await self.waitAndAssertWeeksFor9Eventes(viewModel)
        
        async let weeks = viewModel.weekModels.firstValue(with: self.timeoutMillis)
        self.changeToPDTTimeZone()
        
        // then
        // 이벤트가 16시간씩 앞으로 밀림 -> 1일씩 밀림
        let lastWeek = try await weeks?.last
        let lastWeekEvents = try await viewModel.eventStack(at: lastWeek?.id ?? "")
            .firstValue(with: self.timeoutMillis)
        XCTAssertEqual(lastWeekEvents?.eventIds, [
            ["schedule_event_repeating-6", "2023-09-28-추석", "2023-09-29-추석", "2023-09-30-추석"],
            ["schedule_event_repeating-5", "schedule_event_repeating-7"]
        ])
        XCTAssertEqual(lastWeekEvents?.daysSequences, [
            [(2...4), (5...5), (6...6), (7...7)],
            [(1...2), (7...7)]
        ])
    }
}

// MARK: - notify selected day

extension MonthViewModelImpleTests {
    
    // 9.10 ~ 9.16 주 이벤트 배치
    // 10~13 -> todo_w2_sun_wed / 12~15 -> schedule_w2_tue_fri
    // 1st 11일 선택 -> 이벤트 [todo_w2_sun_wed]
    // 2nd 13일 선택 -> 이벤트 [todo_w2_sun_wed, schedule_w2_tue_fri]
    // 3rd 15일 선택 -> 이벤트 [schedule_w2_tue_fri, schedule_event_repeating]
    // 4th 16일 선택 -> 이벤트 [schedule_event_repeating]
    // 5th 29일 선택 -> 이벤트 [
    func testViewModel_whenSelectedDayChanged_notify() {
        // given
        let viewModel = self.makeViewModelWithStubEvents()
        viewModel.updateMonthIfNeed(.init(year: 2023, month: 09))
        
        func parameterizeTest(
            _ expectDay: String,
            _ expectEventIds: [String],
            _ expectHasHoliday: Bool,
            _ action: () -> Void
        ) {
            // given
            let expect = expectation(description: "wait selected day notified")
            var model: CurrentSelectDayModel?; var eventIds: [String]?
            self.spyListener?.didCurrentDayChanged = {
                model = $0; eventIds = $1.map { $0.eventId }
                expect.fulfill()
            }
            
            // when
            action()
            self.wait(for: [expect], timeout: self.timeout)
            
            // then
            XCTAssertEqual(model?.identifier, expectDay)
            XCTAssertEqual(eventIds, expectEventIds)
            XCTAssertEqual(model?.holiday != nil, expectHasHoliday)
        }
        
        // when + then
        parameterizeTest("2023-9-11", ["todo_w2_sun_wed"], false) {
            viewModel.select(.init(2023, 9, 11))
        }
        parameterizeTest("2023-9-13", ["todo_w2_sun_wed", "schedule_w2_tue_fri-1"], false) {
            viewModel.select(.init(2023, 9, 13))
        }
        parameterizeTest("2023-9-15", ["schedule_event_repeating-4", "schedule_w2_tue_fri-1"], false) {
            viewModel.select(.init(2023, 9, 15))
        }
        parameterizeTest("2023-9-16", ["schedule_event_repeating-4"], false) {
            viewModel.select(.init(2023, 9, 16))
        }
        parameterizeTest("2023-9-29", ["2023-09-29-추석"], true) {
            viewModel.select(.init(2023, 09, 29))
        }
    }
}

extension MonthViewModelImpleTests {
    
    private func makeViewModelWith8Loaded() -> MonthViewModelImple {
        // given
        let expect = expectation(description: "wait")
        expect.assertForOverFulfill = false
        let viewModel = self.makeViewModelWithStubEvents()
        // when
        let _ = self.waitFirstOutput(expect, for: viewModel.weekModels.dropFirst()) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 08))
        }
        // then
        return viewModel
    }
    
    func testViewModel_provideEventsWithFiltering() {
        // given
        let expect = expectation(description: "필터링된 이벤트 목록만 반환")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModelWith8Loaded()
        
        // when
        let eventsIn8ThirdWeek = viewModel.eventStack(at: "2023-8-13-2023-8-19")
        let eventStacks = self.waitOutputs(expect, for: eventsIn8ThirdWeek) {
            self.stubTagUsecase.toggleEventTagIsOnCalendar(.holiday)
            self.stubTagUsecase.toggleEventTagIsOnCalendar(.custom("some"))
            self.stubTagUsecase.toggleEventTagIsOnCalendar(.default)
        }
        
        // then
        let eventIds = eventStacks.map { $0.eventIds }
        
        let eventIds0 = eventIds[safe: 0]
        XCTAssertEqual(eventIds0, [
            ["schedule_event_repeating-2"],
            ["todo8", "2023-08-15-광복절"]
        ])
        let eventIds1 = eventIds[safe: 1]
        XCTAssertEqual(eventIds1, [
            ["schedule_event_repeating-2"],
            ["todo8"]
        ])
        
        let eventIds2 = eventIds[safe: 2]
        XCTAssertEqual(eventIds2, [
            ["schedule_event_repeating-2"]
        ])
        
        let eventIds3 = eventIds[safe: 3]
        XCTAssertEqual(eventIds3, [])
    }
    
    private func toggleShowUnderLineOnEventDay(_ newValue: Bool) {
        let params = EditCalendarAppearanceSettingParams()
            |> \.showUnderLineOnEventDay .~ newValue
        _ = try? self.stubUISettingUsecase.changeCalendarAppearanceSetting(params)
    }
    
    func testViewModel_provideEventsWithUnderLineDays() {
        // given
        let expect = expectation(description: "이벤트 보유 날짜 밑줄표시 여부 변경에 따라 공휴일 제외하고 표시여부 정보도 같이 반환")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithStubEvents()
        viewModel.updateMonthIfNeed(.init(year: 2023, month: 09))
        
        // when
        let eventsIn8ThirdWeek = viewModel.eventStack(at: "2023-9-24-2023-9-30")
        let eventStacks = self.waitOutputs(expect, for: eventsIn8ThirdWeek) {
            self.toggleShowUnderLineOnEventDay(true)
            self.toggleShowUnderLineOnEventDay(false)
        }
        
        // then
        let showUnderLineDays = eventStacks.map { $0.shouldShowEventLinesDays }
        XCTAssertEqual(showUnderLineDays, [
            [],
            [24, 25, 26, 27, 28],
            []
        ])
    }
}

// MARK: - doubles

extension MonthViewModelImpleTests {

    private class PrivateStubCalendarUsecase: StubCalendarUsecase {

        override func components(for month: Int, of year: Int) -> AnyPublisher<CalendarComponent, Never> {
            if month == 9 && year == 2023 {
                let dummy = CalendarComponent.dummy2023_9()
                return Just(dummy).eraseToAnyPublisher()
            } else if month == 8 && year == 2023 {
                let dummy = CalendarComponent.dummy2023_8()
                return Just(dummy).eraseToAnyPublisher()
            } else {
                return Empty().eraseToAnyPublisher()
            }
        }
    }

    private class PrivateStubTodoUsecase: StubTodoEventUsecase {

        var eventsFor8: [TodoEvent] = [] {
            didSet {
                self.subjectFor8.send(eventsFor8)
            }
        }
        var eventsFor9: [TodoEvent] = [] {
            didSet {
                self.subjectFor9.send(eventsFor9)
            }
        }

        private let subjectFor9 = CurrentValueSubject<[TodoEvent], Never>([])
        private let subjectFor8 = CurrentValueSubject<[TodoEvent], Never>([])

        override func todoEvents(in period: Range<TimeInterval>) -> AnyPublisher<[TodoEvent], Never> {
            switch period.centerDateMonth() {
            case 9:
                return self.subjectFor9.eraseToAnyPublisher()
            case 8:
                return self.subjectFor8.eraseToAnyPublisher()
            default: return Empty().eraseToAnyPublisher()
            }
        }
    }

    private class PrivateStubScheduleUsecase: StubScheduleEventUsecase {

        var eventsFor8: [ScheduleEvent] = [] {
            didSet {
                self.subjectFor8.send(eventsFor8)
            }
        }
        var eventsFor9: [ScheduleEvent] = [] {
            didSet {
                self.subjectFor9.send(eventsFor9)
            }
        }

        private let subjectFor9 = CurrentValueSubject<[ScheduleEvent], Never>([])
        private let subjectFor8 = CurrentValueSubject<[ScheduleEvent], Never>([])

        override func scheduleEvents(in period: Range<TimeInterval>) -> AnyPublisher<[ScheduleEvent], Never> {
            switch period.centerDateMonth() {
            case 9:
                return self.subjectFor9.eraseToAnyPublisher()
            case 8:
                return self.subjectFor8.eraseToAnyPublisher()
            default: return Empty().eraseToAnyPublisher()
            }
        }
    }
    
    private class SpyListener: MonthSceneListener {
        
        var didCurrentDayChanged: ((CurrentSelectDayModel, [any CalendarEvent]) -> Void)?
        func monthScene(didChange currentSelectedDay: CurrentSelectDayModel, and eventsThatDay: [any CalendarEvent]) {
            self.didCurrentDayChanged?(currentSelectedDay, eventsThatDay)
        }
    }
}

private extension Range where Bound == TimeInterval {

    func centerDateMonth() -> Int {
        let center = (self.lowerBound + self.upperBound) / 2
        let centerDate = Date(timeIntervalSince1970: center)
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ TimeZone(abbreviation: "KST")!
        return calendar.component(.month, from: centerDate)
    }
}

private extension EventTime {

    private static func date(_ month: Int, _ day: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ TimeZone(abbreviation: "KST")!
        let compos = DateComponents(year: 2023, month: month, day: day, hour: 12)
        return calendar.date(from: compos)!
    }

    static func dummyAt(_ month: Int, _ day: Int) -> EventTime {
        let date = self.date(month, day)
        return .at(date.timeIntervalSince1970)
    }

    static func dummyPeriod(from : (Int, Int), to: (Int, Int)) -> EventTime {
        let start = self.date(from.0, from.1)
        let end = self.date(to.0, to.1)
        return .period(
            start.timeIntervalSince1970
                ..<
            end.timeIntervalSince1970
        )
    }
}


private extension WeekEventStackViewModel {
    
    var eventIds: [[String]] {
        return self.linesStack.map { lines in lines.map { $0.eventId } }
    }
    
    var daysSequences: [[ClosedRange<Int>]] {
        return self.linesStack.map { lines in lines.map { $0.eventOnWeek.daysSequence } }
    }
}

private extension DayCellViewModel {
    
    init(_ year: Int, _ month: Int, _ day: Int) {
        self.init(year: year, month: month, day: day, isNotCurrentMonth: false, accentDay: nil)
    }
}

private extension String {
    
    func asHoliday(_ name: String) -> Holiday {
        return .init(dateString: self, localName: name, name: name)
    }
}
