//
//  CalendarViewModelImpleTests.swift
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


class CalendarViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubSettingUsecase: StubCalendarSettingUsecase!
    private var stubTodoUsecase: PrivateStubTodoUsecase!
    private var stubScheduleUsecase: PrivateStubScheduleUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubSettingUsecase = .init()
        self.stubTodoUsecase = .init()
        self.stubScheduleUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubSettingUsecase = nil
        self.stubTodoUsecase = nil
        self.stubScheduleUsecase = nil
    }
    
    private func makeViewModel() -> CalendarViewModelImple {
        let calendarUsecase = PrivateStubCalendarUsecase(
            today: .init(year: 2023, month: 09, day: 10, weekDay: 1)
        )
        self.stubSettingUsecase.prepare()
        
        let viewModel = CalendarViewModelImple(
            calendarUsecase: calendarUsecase,
            calendarSettingUsecase: self.stubSettingUsecase,
            todoUsecase: self.stubTodoUsecase,
            scheduleEventUsecase: self.stubScheduleUsecase
        )
        return viewModel
    }
}


// MARK: - provide components

extension CalendarViewModelImpleTests {
    
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

extension CalendarViewModelImpleTests {
 
    func testViewModel_whenCurrentMonthIsEqualTodayMonth_defaultSelectionDayIsToday() {
        // given
        let expect = expectation(description: "지정된 달이 오늘과 같은 달이면 현재 날짜 디폴트로 선택")
        let viewModel = self.makeViewModel()
        
        // when
        let selected = self.waitFirstOutput(expect, for: viewModel.currentSelectDayIdentifier) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 9))
        }
        
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
                .init(year: 2023, month: 9, day: 23, isNotCurrentMonth: false)
            )
        }
        
        // then
        XCTAssertEqual(selecteds, [
            "2023-9-10", "2023-9-23"
        ])
    }
}


// MARK: - test events

extension CalendarViewModelImpleTests {
    
    private func dummyEvent(_ range: ClosedRange<Int>) -> EventOnWeek {
        let dummyRange: Range<TimeInterval> = 0..<1
        return .init(eventRangesOnWeek: dummyRange, weekDaysRange: range, eventId: .todo("todo:\(range)"))
    }
    
    // 해당 요일에 존재하는 이벤트 포함
    func testDayCellViewModel_withEvent() {
        // given
        let wednesday = CalendarComponent.Day(year: 2023, month: 09, day: 06, weekDay: 4)
        let stacks: [[EventOnWeek]] = [
            [self.dummyEvent(1...3), self.dummyEvent(5...6)],
            [self.dummyEvent(2...5)],
            [self.dummyEvent(4...4)]
        ]
        
        // when
        let cellViewModel = DayCellViewModel(wednesday, month: 09, stack: stacks)
        
        // then
        let isBlanks = cellViewModel.events.map { $0.isBank }
        let eventIdsOnWednesday = cellViewModel.events.map { $0.eventId }
        XCTAssertEqual(isBlanks, [true, false, false])
        XCTAssertEqual(eventIdsOnWednesday, [
            nil, .todo("todo:2...5"), .todo("todo:4...4")
        ])
    }
    
    // 이벤트 포함시에 bound 정보도 같이 포함
    func testDayCellViewModel_whenContainsEvent_provideBoundInfo() {
        // given
        let wednesday = CalendarComponent.Day(year: 2023, month: 09, day: 06, weekDay: 4)
        let stacks: [[EventOnWeek]] = [
            [self.dummyEvent(1...2), self.dummyEvent(3...3), self.dummyEvent(5...7)],
            [self.dummyEvent(2...4), self.dummyEvent(5...5)],
            [self.dummyEvent(2...5)],
            [self.dummyEvent(4...5)],
            [self.dummyEvent(4...4)]
        ]
        
        // when
        let cellViewModel = DayCellViewModel(wednesday, month: 09, stack: stacks)
        
        // then
        let isBlanks = cellViewModel.events.map { $0.isBank }
        let eventBoundForWednesDay = cellViewModel.events.map { $0.bound }
        XCTAssertEqual(isBlanks, [true, false, false, false, false])
        XCTAssertEqual(eventBoundForWednesDay, [nil, .end, nil, .start, nil])
    }
    
    private func makeViewModelWithStubEvents() -> CalendarViewModelImple {
        let todo_w2_sun_wed = TodoEvent(uuid: "todo_w2_sun_wed", name: "some")
            |> \.time .~ .dummyPeriod(from: (09, 10), to: (09, 13))
        let todo_w1_mon = TodoEvent(uuid: "todo_w1_mon", name: "some")
            |> \.time .~ .dummyAt(08, 28)
        let pdtTimeZone = TimeZone(abbreviation: "PDT")!
        let range = try! TimeInterval.range(
            from: "2023-08-29 00:00:00", to: "2023-08-29 23:59:59", in: pdtTimeZone
        )
        let todo8_29_allday = TodoEvent(uuid: "todo8_29_allday", name: "allday")
            |> \.time .~ .allDay(range, secondsFromGMT: pdtTimeZone.secondsFromGMT() |> TimeInterval.init)
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
    
    private func assertWeeksFor9(_ weeks: [WeekRowModel]) {
        let eventIdLists = weeks.map { $0.eventIds }
        XCTAssertEqual(eventIdLists.count, 5)
        
        let expectWeek1: [[EventId?]] = [
            [.schedule("schedule_event_repeating", turn: 3), nil],
            [.schedule("schedule_event_repeating", turn: 3), .todo("todo_w1_mon")],
            [.schedule("schedule_event_repeating", turn: 3), .todo("todo8_29_allday")],
            [nil, nil], [nil, nil], [nil, nil], [nil, nil]
        ]
        XCTAssertEqual(eventIdLists[safe: 0], expectWeek1)
        
        let expectWeek2: [[EventId?]] = Array(repeating: [], count: 7)
        XCTAssertEqual(eventIdLists[safe: 1], expectWeek2)
        
        let expectWeek3: [[EventId?]] = [
            [.todo("todo_w2_sun_wed"), nil],  // 9.10
            [.todo("todo_w2_sun_wed"), nil],  // 9.11
            [.todo("todo_w2_sun_wed"), .schedule("schedule_w2_tue_fri", turn: 1)],  // 9.12
            [.todo("todo_w2_sun_wed"), .schedule("schedule_w2_tue_fri", turn: 1)],  // 9.13
            [.schedule("schedule_event_repeating", turn: 4), .schedule("schedule_w2_tue_fri", turn: 1)], // 9.14
            [.schedule("schedule_event_repeating", turn: 4), .schedule("schedule_w2_tue_fri", turn: 1)], // 9.15
            [.schedule("schedule_event_repeating", turn: 4), nil]    // 9.16
        ]
        XCTAssertEqual(eventIdLists[safe: 2], expectWeek3)
        
        let expectWeek4: [[EventId?]] = [
            [nil], [nil], // 9.17, 9.18
            [.schedule("schedule_event_repeating", turn: 5)],  // 9.19
            [.schedule("schedule_event_repeating", turn: 5)],  // 9.20
            [.schedule("schedule_event_repeating", turn: 5)],  // 9.21
            [.schedule("schedule_event_repeating", turn: 5)],  // 9.22
            [.schedule("schedule_event_repeating", turn: 5)],  // 9.23
        ]
        XCTAssertEqual(eventIdLists[safe: 3], expectWeek4)
        
        let expectWeek5: [[EventId?]] = [
            [.schedule("schedule_event_repeating", turn: 5), nil],  // 9.24
            [.schedule("schedule_event_repeating", turn: 5), nil],  // 9.25
            [.schedule("schedule_event_repeating", turn: 5), .schedule("schedule_event_repeating", turn: 6)],  // 9.26
            [nil, .schedule("schedule_event_repeating", turn: 6)], // 9.27
            [.holiday("2023-09-28", name: "추석"), .schedule("schedule_event_repeating", turn: 6)], // 9.28
            [.holiday("2023-09-29", name: "추석"), nil], // 9.29
            [.holiday("2023-09-30", name: "추석"), nil] // 9.30
        ]
        XCTAssertEqual(eventIdLists[safe: 4], expectWeek5)
    }
    
    private func assertWeeksFor8(_ weeks: [WeekRowModel]) {
        let eventIdLists = weeks.map { $0.eventIds }
        XCTAssertEqual(eventIdLists.count, 5)
        
        XCTAssertEqual(eventIdLists[safe: 0], [
            [.schedule("schedule_event_repeating", turn: 1)],
            [.schedule("schedule_event_repeating", turn: 2)],
            [.schedule("schedule_event_repeating", turn: 2)],
            [.schedule("schedule_event_repeating", turn: 2)],
            [.schedule("schedule_event_repeating", turn: 2)],
            [.schedule("schedule_event_repeating", turn: 2)],
            [.schedule("schedule_event_repeating", turn: 2)]
        ])
        XCTAssertEqual(eventIdLists[safe: 1], Array(repeating: [
            .schedule("schedule_event_repeating", turn: 2)
        ], count: 7))
        XCTAssertEqual(eventIdLists[safe: 2], [
            [.schedule("schedule_event_repeating", turn: 2), .todo("todo8")],
            [.schedule("schedule_event_repeating", turn: 2), nil],
            [.schedule("schedule_event_repeating", turn: 2), .holiday("2023-08-15", name: "광복절")],
            [.schedule("schedule_event_repeating", turn: 2), nil],
            [nil, nil], [nil, nil], [nil, nil]
        ])
        XCTAssertEqual(eventIdLists[safe: 3], [
            [nil], [nil], [nil], [nil], [nil],
            [.schedule("schedule_event_repeating", turn: 3)],
            [.schedule("schedule_event_repeating", turn: 3)]
        ])
        XCTAssertEqual(eventIdLists[safe: 4], [
            [.schedule("schedule_event_repeating", turn: 3), nil],
            [.schedule("schedule_event_repeating", turn: 3), .todo("todo_w1_mon")],
            [.schedule("schedule_event_repeating", turn: 3), .todo("todo8_29_allday")],
            [nil, nil], [nil, nil], [nil, nil], [nil, nil]
        ])
    }
    
    // 이벤트 정보와 함께 달력 정보 제공 + 이때 해당되는 일정의 todo만, 해당 월에서 반복시간이 없는 스케쥴이나, 반복시간이 해당 월에 매칭되는 경우만 반환
    func testViewModel_provideWeekModelsWithEvent() {
        // given
        let expect = expectation(description: "이벤트 정보와 함께 달력 정보 제공 + 이때 해당되는 일정의 todo만, 해당 월에서 반복시간이 없는 스케쥴이나, 반복시간이 해당 월에 매칭되는 경우만 반환")
        expect.assertForOverFulfill = false
        let viewModel = self.makeViewModelWithStubEvents()
        
        // when
        let source = viewModel.weekModels
        let weeks = self.waitFirstOutput(expect, for: source, timeout: 0.1) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 9))
        } ?? []
        
        // then
        self.assertWeeksFor9(weeks)
    }
    
    // 달 변경시에 변경된 이벤트 방출
    func testViewModel_whenAfterChangeMonth_updateWeekModelWithEvents() {
        // given
        let expect = expectation(description: "달 변경 이후에 변경된 달의 이벤트 정보도 같이 방출")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithStubEvents()
        
        // when
        let weekModelLists = self.waitOutputs(expect, for: viewModel.weekModels) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 09))
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 08))
        }
        
        // then
        XCTAssertEqual(weekModelLists.count, 2)
        assertWeeksFor9(weekModelLists.first ?? [])
        assertWeeksFor8(weekModelLists.last ?? [])
    }
    
    func testViewModel_whenEventStackChangesOnMonth_updateWeekModels() {
        // given
        let expect = expectation(description: "이벤트 변경되면 이벤트 구성 바뀌어서 방출")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithStubEvents()
        
        // when
        let weekModelLists = self.waitOutputs(expect, for: viewModel.weekModels) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 09))
            self.removeTodo0828()
        }
        
        // then
        XCTAssertEqual(weekModelLists.count, 2)
        self.assertWeeksFor9(weekModelLists.first ?? [])
        
        let newWeeksFirstWeek = weekModelLists.last?.first
        let expectWeek1: [[EventId?]] = [
            [.schedule("schedule_event_repeating", turn: 3), nil],
            [.schedule("schedule_event_repeating", turn: 3), nil],
            [.schedule("schedule_event_repeating", turn: 3), .todo("todo8_29_allday")],
            [nil, nil], [nil, nil], [nil, nil], [nil, nil]
        ]
        XCTAssertEqual(newWeeksFirstWeek?.eventIds, expectWeek1)
    }
    
    func testViewModel_whenTimeZoneChanges_updateWeekModelWithNewEventRange() {
        // given
        let expect = expectation(description: "타임존 바뀌면 전체 표현 범위 변하고 포함되는 이벤트 다시 계산해서 방출")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithStubEvents()
        
        // when
        let weekModelLists = self.waitOutputs(expect, for: viewModel.weekModels) {
            viewModel.updateMonthIfNeed(.init(year: 2023, month: 09))
            self.changeToPDTTimeZone()
        }
        
        // then
        XCTAssertEqual(weekModelLists.count, 2)
        self.assertWeeksFor9(weekModelLists.first ?? [])
        
        // 이벤트가 16시간씩 앞으로 밀림 -> 1일씩 밀림
        let newWeeksLastWeek = weekModelLists.last?.last
        let expectWeek5: [[EventId?]] = [
            [nil, .schedule("schedule_event_repeating", turn: 5)],  // 9.24
            [.schedule("schedule_event_repeating", turn: 6), .schedule("schedule_event_repeating", turn: 5)],  // 9.25
            [.schedule("schedule_event_repeating", turn: 6), nil],  // 9.26
            [.schedule("schedule_event_repeating", turn: 6), nil], // 9.27
            [.holiday("2023-09-28", name: "추석"), nil], // 9.28
            [.holiday("2023-09-29", name: "추석"), nil],
            [.holiday("2023-09-30", name: "추석"), .schedule("schedule_event_repeating", turn: 7)] // 9.29, 9.30
        ]
        XCTAssertEqual(newWeeksLastWeek?.eventIds, expectWeek5)
    }
}

// MARK: - doubles

extension CalendarViewModelImpleTests {
    
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

private extension DayCellViewModel.EventSummary {
    
    var isBank: Bool {
        switch self {
        case .blank: return true
        case .event: return false
        }
    }
    
    var eventId: EventId? {
        switch self {
        case .event(let id, _): return id
        case .blank: return nil
        }
    }
    
    var bound: Bound? {
        switch self {
        case .blank: return nil
        case .event(_, let bound): return bound
        }
    }
}

private extension WeekRowModel {
    
    var eventIds: [[EventId?]] {
        return self.days.map { day in day.events.map { $0.eventId } }
    }
}
