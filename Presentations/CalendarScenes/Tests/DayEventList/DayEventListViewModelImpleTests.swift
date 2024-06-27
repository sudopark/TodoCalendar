//
//  DayEventListViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 2023/09/03.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Scenes
import UnitTestHelpKit
import TestDoubles

@testable import CalendarScenes


class DayEventListViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubTodoUsecase: PrivateStubTodoEventUsecase!
    private var stubScheduleUsecase: StubScheduleEventUsecase!
    private var stubForemostEventUsecase: StubForemostEventUsecase!
    private var stubTagUsecase: StubEventTagUsecase!
    private var spyRouter: SpyRouter!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubTodoUsecase = .init()
        self.stubScheduleUsecase = .init()
        self.stubTagUsecase = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubTodoUsecase = nil
        self.stubScheduleUsecase = nil
        self.stubForemostEventUsecase = nil
        self.stubTagUsecase = nil
        self.spyRouter = nil
    }
    
    // 9-10일: current-todo-1, current-todo-2, todo-with-time, not-repeating-schedule, repeating-schedule(turn 4)
    // 9-11일: current-todo-1, current-todo-2
    private func makeViewModel(
        foremostEventId: ForemostEventId? = nil,
        shouldFailDoneTodo: Bool = false,
        shouldFailMakeTodo: Bool = false
    ) -> DayEventListViewModelImple {
        let currentTodos: [TodoEvent] = [
            .init(uuid: "current-todo-1", name: "current-todo-1"),
            .init(uuid: "current-todo-2", name: "current-todo-2")
        ]

        self.stubTodoUsecase.stubCurrentTodoEvents = currentTodos
        self.stubTodoUsecase.shouldFailCompleteTodo = shouldFailDoneTodo
        self.stubTodoUsecase.shouldFailMakeTodo = shouldFailMakeTodo
        
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.selectTimeZone(TimeZone(abbreviation: "KST")!)
        
        let uiSettingUsecase = StubUISettingUsecase()
        var setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "", default: "")
        )
        setting.calendar.is24hourForm = true
        uiSettingUsecase.stubAppearanceSetting = setting
        _ = uiSettingUsecase.loadSavedAppearanceSetting()
        
        self.stubForemostEventUsecase = .init(foremostId: foremostEventId)
        self.stubForemostEventUsecase.refresh()
        
        let viewModel = DayEventListViewModelImple(
            calendarSettingUsecase: calendarSettingUsecase,
            todoEventUsecase: self.stubTodoUsecase,
            scheduleEventUsecase: self.stubScheduleUsecase,
            foremostEventUsecase: self.stubForemostEventUsecase,
            eventTagUsecase: self.stubTagUsecase,
            uiSettingUsecase: uiSettingUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
    
    private func september10th() -> CurrentSelectDayModel {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ TimeZone(abbreviation: "KST")!
        let component = DateComponents(year: 2023, month: 9, day: 10)
        let start = calendar.date(from: component)!.timeIntervalSince1970
        return .init(2023, 9, 10, weekId: "some", range: start..<start+3600*24)
    }
    
    private func september11th() -> CurrentSelectDayModel {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ TimeZone(abbreviation: "KST")!
        let component = DateComponents(year: 2023, month: 9, day: 11)
        let start = calendar.date(from: component)!.timeIntervalSince1970
        return .init(2023, 9, 11, weekId: "some", range: start..<start+3600*24)
    }
}


extension DayEventListViewModelImpleTests {
    
    func testViewModel_provideSelectedDayTitle() {
        // given
        let expect = expectation(description: "선택된 날짜 정보 제공")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let selectedDays = self.waitOutputs(expect, for: viewModel.selectedDay) {
            viewModel.selectedDayChanaged(self.september10th(), and: [])
            viewModel.selectedDayChanaged(self.september11th(), and: [])
        }
        
        // then
        XCTAssertEqual(selectedDays.map { $0.dateText }, [
            "2023 09 10 (Sun)",
            "2023 09 11 (Mon)"
        ])
        XCTAssertEqual(selectedDays.map { $0.lunarDateText }, [
            "07 26",
            "07 27"
        ])
    }
}

// current todo -> 상시
extension DayEventListViewModelImpleTests {
    
    func testCellViewModel_makeFromCurrentTodo() {
        // given
        let timeZone = TimeZone(abbreviation: "KST")!
        let current = TodoEvent(uuid: "curent", name: "current todo")
        let event = TodoCalendarEvent(current, in: timeZone)
        
        // when
        let cellViewModel = TodoEventCellViewModel(event, in: 0..<100, timeZone, true)
        
        // then
        XCTAssertEqual(cellViewModel?.name, "current todo")
        XCTAssertEqual(cellViewModel?.periodText, .singleText(
            .init(text: "Todo".localized())
        ))
        XCTAssertEqual(cellViewModel?.periodDescription, nil)
    }
    
    func testCellViewModel_makeFromHoliday() {
        // given
        let holiday = Holiday(dateString: "2020-03-01", localName: "삼일절", name: "삼일절")
        let event = HolidayCalendarEvent(holiday, in: TimeZone(abbreviation: "KST")!)!
        
        // when
        let cellViewModel = HolidayEventCellViewModel(event)
        
        // then
        XCTAssertEqual(cellViewModel.name, "삼일절")
        XCTAssertEqual(cellViewModel.periodText, .singleText(
            .init(text: "Allday".localized())
        ))
        XCTAssertEqual(cellViewModel.periodDescription, nil)
    }
    
    private func september10th(in timeZone: TimeZone) -> Range<TimeInterval> {
        let components = DateComponents(year: 2023, month: 9, day: 10)
        let caleandr = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let date = caleandr.date(from: components)!
        let start = caleandr.startOfDay(for: date)
        let end = caleandr.endOfDay(for: date)!
        return start.timeIntervalSince1970..<end.timeIntervalSince1970
    }
    
    private func september10th10_30AtTime(in timeZone: TimeZone) -> EventTime {
        let component = DateComponents(year: 2023, month: 9, day: 10, hour: 10, minute: 30)
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let date = calendar.date(from: component)!
        return .at(date.timeIntervalSince1970)
    }
    
    private var todayRange: Range<TimeInterval> {
        return september10th(in: TimeZone(abbreviation: "KST")!)
    }
    
    private var rangeFromPastToToday: Range<TimeInterval> {
        return self.todayRange.shift(-100)
    }
    
    private var rangeFromTodayToFuture: Range<TimeInterval> {
        return self.todayRange.shift(100)
    }
    
    private var rangeFromPastToFuture: Range<TimeInterval> {
        let range = self.todayRange
        return range.lowerBound-100..<range.upperBound+100
    }
    
    private var rangeFromTodayToToday: Range<TimeInterval> {
        let range = self.todayRange
        return range.lowerBound+100..<range.upperBound-100
    }
    
    func testCellViewModel_makeFromTodoEventWithTime() {
        // given
        let timeZone = TimeZone(abbreviation: "KST")!
        func parameterizeTest(
            _ range: Range<TimeInterval>?,
            _ expectPeriodText: EventPeriodText
        ) {
            let time = range.map { EventTime.period($0) }
            let todo = TodoEvent(uuid: "todo", name: "dummy") |> \.time .~ time
            let event = TodoCalendarEvent(todo, in: timeZone)
            
            let cellViewModel = TodoEventCellViewModel(event, in: self.todayRange, timeZone, true)
            
            XCTAssertEqual(cellViewModel?.periodText, expectPeriodText)
        }
        // when + then
        parameterizeTest(nil, .singleText(
            .init(text: "Todo".localized())
        ))
        parameterizeTest(self.rangeFromPastToToday, .doubleText(
            .init(text: "Todo".localized()), .init(text: "23:58")
        ))
        parameterizeTest(self.rangeFromTodayToFuture, .doubleText(
            .init(text: "Todo".localized()), .init(text: "11 (Mon)")
        ))
        parameterizeTest(self.rangeFromPastToFuture, .doubleText(
            .init(text: "Todo".localized()), .init(text: "Allday".localized())
        ))
        parameterizeTest(self.rangeFromTodayToToday, .doubleText(
            .init(text: "Todo".localized()), .init(text: "23:58")
        ))
    }
    
    func testCellViewModel_makeFromScheduleEventWithTime() {
        // given
        let timeZone = TimeZone(abbreviation: "KST")!
        func parameterizeTest(
            _ range: Range<TimeInterval>,
            _ expectPeriodText: EventPeriodText
        ) {
            let time = EventTime.period(range)
            let schedule = ScheduleEvent(uuid: "event", name: "some", time: time)
            let event = ScheduleCalendarEvent.events(from: schedule, in: timeZone).first!
            
            let cellViewModel = ScheduleEventCellViewModel(event, in: self.todayRange, timeZone: timeZone, true)
            
            XCTAssertEqual(cellViewModel?.periodText, expectPeriodText)
        }
        // when + then
        parameterizeTest(self.rangeFromPastToToday, .doubleText(
            .init(text: "9 (Sat)"), .init(text: "23:58")
        ))
        parameterizeTest(self.rangeFromTodayToFuture, .doubleText(
            .init(text: "0:01"), .init(text: "11 (Mon)")
        ))
        parameterizeTest(self.rangeFromPastToFuture, .singleText(
            .init(text: "Allday".localized())
        ))
        parameterizeTest(self.rangeFromTodayToToday, .doubleText(
            .init(text: "0:01"), .init(text: "23:58")
        ))
    }
    
    func testCellViewModel_whenEventTimeIsAt_showTimeText() {
        // given
        let timeZone = TimeZone(abbreviation: "KST")!
        let time = self.september10th10_30AtTime(in: timeZone)
        let schedule = ScheduleEvent(uuid: "event", name: "name", time: time)
        let event = ScheduleCalendarEvent.events(from: schedule, in: timeZone).first!
        
        // when
        let cellViewModel = ScheduleEventCellViewModel(event, in: self.todayRange, timeZone: timeZone, true)
        
        // then
        XCTAssertEqual(cellViewModel?.periodText, .singleText(
            .init(text: "10:30")
        ))
    }
    
    private var pdt9_10: Range<TimeInterval> {
        return september10th(in: TimeZone(abbreviation: "PDT")!)
    }
    private var pdt9_9to9_10: Range<TimeInterval> {
        let range = self.pdt9_10
        return range.lowerBound-24*3600..<range.upperBound
    }
    private var pdt9_10to9_11: Range<TimeInterval> {
        let range = self.pdt9_10
        return range.lowerBound..<range.upperBound+24*3600
    }
    private var pdt9_9to9_11: Range<TimeInterval> {
        let range = self.pdt9_10
        return range.lowerBound-24*3600..<range.upperBound+24*3600
    }
    
    func testCellViewModel_whenEventTimeIsAllDay_makeWithCurrentTimeZoneTimeShiftting() {
        // given
        let kstTimeZone = TimeZone(abbreviation: "KST")!
        func parameterizeTest(
            _ range: Range<TimeInterval>,
            _ expectedPeriodText: EventPeriodText
        ) {
            let pdtSecondsFromGMT = TimeZone(abbreviation: "PDT")!
                .secondsFromGMT(for: Date(timeIntervalSince1970: range.lowerBound))
                |> TimeInterval.init
            let time = EventTime.allDay(range, secondsFromGMT: pdtSecondsFromGMT)
            let schedule = ScheduleEvent(uuid: "event", name: "some", time: time)
            let event = ScheduleCalendarEvent.events(from: schedule, in: kstTimeZone).first!
            
            let cellViewModel = ScheduleEventCellViewModel(event, in: self.todayRange, timeZone: kstTimeZone, true)
            
            XCTAssertEqual(cellViewModel?.periodText, expectedPeriodText)
        }
        // when + then
        parameterizeTest(self.pdt9_9to9_10, .singleText(
            .init(text: "Allday".localized())
        ))
        parameterizeTest(self.pdt9_9to9_11, .singleText(
            .init(text: "Allday".localized())
        ))
        parameterizeTest(self.pdt9_10, .singleText(
            .init(text: "Allday".localized())
        ))
        parameterizeTest(self.pdt9_10to9_11, .singleText(
            .init(text: "Allday".localized())
        ))
    }
    
    func testCellViewModel_makeEventWithTimeHasPeriod_setPeriodDesription() {
        // given
        let timeZone = TimeZone(abbreviation: "KST")!
        func parameterizeTest(
            _ time: EventTime,
            _ expectedDescription: String?
        ) {
            let schedule = ScheduleEvent(uuid: "event", name: "some", time: time)
            let event = ScheduleCalendarEvent.events(from: schedule, in: timeZone).first!
            
            let cellViewModel = ScheduleEventCellViewModel(event,in: self.todayRange, timeZone: timeZone, true)
            
            XCTAssertEqual(cellViewModel?.periodDescription, expectedDescription)
        }
        
        // when + then
        let timeAt = EventTime.at(self.todayRange.lowerBound)
        parameterizeTest(timeAt, nil)
        
        let periodHasDays: EventTime = .period(
            self.todayRange.lowerBound-24*3600*3..<self.todayRange.upperBound
        )
        parameterizeTest(periodHasDays, "Sep 7 00:00 ~ Sep 10 23:59(3days 23hours)")
        
        let periodHasNoDays: EventTime = .period(
            self.todayRange.lowerBound-12*3600..<self.todayRange.upperBound-20*3600+1
        )
        parameterizeTest(periodHasNoDays, "Sep 9 12:00 ~ Sep 10 04:00(16hours)")
        
        let periodOnyHasMinutes: EventTime = .period(
            self.todayRange.lowerBound..<self.todayRange.lowerBound+10*60
        )
        parameterizeTest(periodOnyHasMinutes, "Sep 10 00:00 ~ Sep 10 00:10(10minutes)")
        
        let pdtTimeZone = TimeZone(abbreviation: "PDT")!
        let offset = pdtTimeZone.secondsFromGMT(
            for: Date(timeIntervalSince1970: self.pdt9_10.lowerBound)
        ) |> TimeInterval.init
        let allDayToday: EventTime = .allDay(self.pdt9_10, secondsFromGMT: offset)
        parameterizeTest(allDayToday, nil)
        
        let allDay2Days: EventTime = .allDay(self.pdt9_9to9_10, secondsFromGMT: offset)
        parameterizeTest(allDay2Days, "Sep 9 ~ Sep 10(2days)")
    }
    
    func testCellViewModel_moresActions_fromTodo() {
        // given
        func parameterizeTest(_ todo: TodoEvent, isForemost: Bool = false, expectIsRepeating: Bool) {
            // given
            let event = TodoCalendarEvent(todo, in: .current)
                |> \.isForemost .~ isForemost
            
            // when
            let cvm = TodoEventCellViewModel(event, in: 0..<10, .current, false)
            
            // then
            XCTAssertEqual(cvm?.isRepeating, expectIsRepeating)
            XCTAssertEqual(cvm?.isForemost, isForemost)
        }
        let dummyRepeating = EventRepeating(repeatingStartTime: 0, repeatOption: EventRepeatingOptions.EveryDay())
        
        // when + then
        parameterizeTest(
            TodoEvent(uuid: "current", name: "some"),
            expectIsRepeating: false
        )
        parameterizeTest(
            TodoEvent(uuid: "current", name: "some"), 
            isForemost: true,
            expectIsRepeating: false
        )
        parameterizeTest(
            TodoEvent(uuid: "some", name: "some") |> \.time .~ .at(0),
            expectIsRepeating: false
        )
        parameterizeTest(
            TodoEvent(uuid: "some", name: "some")
            |> \.time .~ .at(0) |> \.repeating .~ dummyRepeating,
            expectIsRepeating: true
        )
    }
    
    func testCellViewModel_moresActions_fromSchedule() {
        // given
        func parameterizeTest(_ schedule: ScheduleEvent, isForemost: Bool = false, expectIsRepeating: Bool) {
            // given
            let event = ScheduleCalendarEvent.events(from: schedule, in: .current, foremostId: isForemost ? schedule.uuid : nil).first!
            
            // when
            let cvm = ScheduleEventCellViewModel(event, in: 0..<1, timeZone: .current, false)
            
            // then
            XCTAssertEqual(cvm?.isRepeating, expectIsRepeating)
            XCTAssertEqual(cvm?.isForemost, isForemost)
        }
        let dummyRepeating = EventRepeating(repeatingStartTime: 0, repeatOption: EventRepeatingOptions.EveryDay())
        
        // when + then
        parameterizeTest(
            ScheduleEvent(uuid: "some", name: "some", time: .at(0)),
            expectIsRepeating: false
        )
        parameterizeTest(
            ScheduleEvent(uuid: "some", name: "some", time: .at(0)),
            isForemost: true,
            expectIsRepeating: false
        )
        parameterizeTest(
            ScheduleEvent(uuid: "some", name: "some", time: .at(0)) |> \.repeating .~ dummyRepeating,
            expectIsRepeating: true
        )
    }
}

extension DayEventListViewModelImpleTests {
    
    private var dummyCurrentDay: CurrentSelectDayModel {
        return .init(2023, 09, 10, weekId: "week_1", range: self.todayRange)
    }
    
    private var dummyEvents: [any CalendarEvent] {
        let timeZone = TimeZone(abbreviation: "KST")!
        let holiday = HolidayCalendarEvent(.init(dateString: "2023-09-30", localName: "holiday", name: "holiday"), in: timeZone)!
        let schedule4 = ScheduleEvent(uuid: "repeating-schedule", name: "repeating-schedule", time: .at(0)) |> \.nextRepeatingTimes .~ [.init(time: .at(self.todayRange.lowerBound), turn: 4)]
            |> \.eventTagId .~ .custom("some")
        let scheduleWithRepeating = ScheduleCalendarEvent.events(from: schedule4, in: timeZone).last!
        let todo = TodoCalendarEvent(.init(uuid: ("todo-with-time"), name: "todo-with-time") |> \.eventTagId .~ .custom("some"), in: timeZone)
        let scheduleWithoutRepeating = ScheduleCalendarEvent(
            eventIdWithoutTurn: "ev",
            eventId: "not-repeating-schedule", 
            name: "not-repeating-schedule",
            eventTime: .at(self.todayRange.lowerBound),
            eventTimeOnCalendar: nil,
            eventTagId: .custom("some"),
            isRepeating: false
        ) |> \.turn .~ 1
        return [
            holiday, scheduleWithRepeating, todo, scheduleWithoutRepeating
        ]
    }
    
    private var dummyEventIdStrings: [String] {
        return [
            "2023-09-30-holiday",
            "repeating-schedule-4",
            "todo-with-time",
            "not-repeating-schedule"
        ]
    }
    
    // 선택된 날짜에 해당하는 이벤트 리스트 제공 + 이경우에 current todo 정보도 같이 제공
    func testViewModel_provideEventListThatDayWithCurrentTodo() {
        // given
        let expect = expectation(description: "해당 하는 날짜의 이벤트 목록을 current todo와 함께 제공")
        let viewModel = self.makeViewModel(
            foremostEventId: .init("current-todo-2", true)
        )
        
        // when
        let source = viewModel.cellViewModels.drop(while: { $0.count != self.dummyEvents.count + 2 })
        let cvms = self.waitFirstOutput(expect, for: source, timeout: 0.1) {
            viewModel.selectedDayChanaged(self.dummyCurrentDay, and: self.dummyEvents)
        }
        
        // then
        let eventIdLists = cvms?.map { $0.eventIdentifier }
        let isForemosts = cvms?.map { $0.isForemost }
        XCTAssertEqual(eventIdLists, [
            "current-todo-1", "current-todo-2"
        ] + self.dummyEventIdStrings)
        XCTAssertEqual(isForemosts, [false, true, false, false, false, false])
    }
    
    private func makeViewModelWithInitialListLoaded(
        shouldFailDoneTodo: Bool = false,
        shouldFailMakeTodo: Bool = false
    ) -> DayEventListViewModelImple {
        // given
        let expect = expectation(description: "wait first cells loaded")
        expect.assertForOverFulfill = false
        let viewModel = self.makeViewModel(
            shouldFailDoneTodo: shouldFailDoneTodo,
            shouldFailMakeTodo: shouldFailMakeTodo
        )
        
        // when
        let source = viewModel.cellViewModels.drop(while: { $0.count != self.dummyEvents.count + 2 })
        let _ = self.waitFirstOutput(expect, for: source) {
            viewModel.selectedDayChanaged(self.dummyCurrentDay, and: self.dummyEvents)
        }
        
        // then
        return viewModel
    }
    
    func testViewModel_provideEventListWithoutOffTagEvent() {
        // given
        let expect = expectation(description: "이벤트 목록 제공시에 비활성화된 태그에 해당하는 이벤트는 제외")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialListLoaded()
        
        // when
        let cvmLists = self.waitOutputs(expect, for: viewModel.cellViewModels) {
            self.stubTagUsecase.toggleEventTagIsOnCalendar(.default)
        }
        
        // then
        let hasCurrentTodo = cvmLists
            .map { $0.filter { $0.name.starts(with: "current-todo") }}
            .map { !$0.isEmpty }
        XCTAssertEqual(hasCurrentTodo, [true, false])
    }
}

// MARK: - test make new todo quickly

extension DayEventListViewModelImpleTests {
    
    private var totalEventNameListWithoutPending: [String] {
        return [
            "current-todo-1", "current-todo-2",
            "holiday",
            "repeating-schedule",
            "todo-with-time",
            "not-repeating-schedule"
        ]
    }
    
    private var totalEventNameListsWithPending: [String] {
        return [
            "current-todo-1", "current-todo-2",
            "pending-quick-todo",
            "holiday",
            "repeating-schedule",
            "todo-with-time",
            "not-repeating-schedule"
        ]
    }
    
    func testViewModel_whenMakeNewTodoQuickly_appendPendingCellAndInvalidate() {
        // given
        let expect = expectation(description: "빠르게 todo 생성시에 pendingcell 방출하고 이후 제거")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithInitialListLoaded()
        
        // when
        let cvmLists = self.waitOutputs(expect, for: viewModel.cellViewModels) {
            viewModel.addNewTodoQuickly(withName: "pending-quick-todo")
        }
        
        // then
        let nameLists = cvmLists.map { $0.map { $0.name } }
        XCTAssertEqual(nameLists, [
            self.totalEventNameListWithoutPending,
            self.totalEventNameListsWithPending,
            self.totalEventNameListWithoutPending
        ])
    }
    
    func testViewModel_whenMakeNewTodoQuicklyFails_removePendingTodo() {
        // given
        let expect = expectation(description: "빠르게 todo 생성 실패시에도 pendingcell 방출하고 이후 제거")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithInitialListLoaded(shouldFailMakeTodo: true)
        
        // when
        let cvmLists = self.waitOutputs(expect, for: viewModel.cellViewModels) {
            viewModel.addNewTodoQuickly(withName: "pending-quick-todo")
        }
        
        // then
        let nameLists = cvmLists.map { $0.map { $0.name } }
        XCTAssertEqual(nameLists, [
            self.totalEventNameListWithoutPending,
            self.totalEventNameListsWithPending,
            self.totalEventNameListWithoutPending
        ])
    }
    
    func testViewModel_whenMakeNewTodoQuicklyFails_showError() {
        // given
        let expect = expectation(description: "빠르게 todo 생성 실패시에 에러 알림")
        let viewModel = self.makeViewModel(shouldFailMakeTodo: true)
        self.spyRouter.didShowErrorCallback = { _ in
            expect.fulfill()
        }
        // when
        viewModel.addNewTodoQuickly(withName: "pending-quick-todo")
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
}

// MARK: - test make events

extension DayEventListViewModelImpleTests {
    
    func testViewModel_makeTodoWithGivenName() {
        // given
        let viewModel = self.makeViewModel()
        viewModel.selectedDayChanaged(self.september10th(), and: [])
        
        // when
        viewModel.makeTodoEvent(with: "some")
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToMakeNewEventWithParams?.initialTodoInfo?.name, "some")
    }
    
    // TODO: evnet 생성 기능 추가한 이후에 구현
//    func testViewModel_makeNewEvent() {
//
//    }
//
//    func testViewModel_makeNewEventUsingTemplate() {
//        // given
//        // when
//        // then
//    }
}

extension DayEventListViewModelImpleTests {
    
    func testViewModel_showDoneTodoList() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.showDoneTodoList()
        
        // then
        XCTAssertEqual(self.spyRouter.didShowDoneTodoList, true)
    }
}

extension DayEventListViewModelImpleTests {
    
    private class SpyRouter: BaseSpyRouter, DayEventListRouting, @unchecked Sendable {
        
        var didRouteToMakeNewEventWithParams: MakeEventParams?
        func routeToMakeNewEvent(_ withParams: MakeEventParams) {
            self.didRouteToMakeNewEventWithParams = withParams
        }
        
        func routeToMakeNewEvent() {
            
        }
        
        func routeToSelectTemplateForMakeEvent() {
            
        }
        
        var didShowDoneTodoList: Bool?
        func showDoneTodoList() {
            self.didShowDoneTodoList = true
        }
    }
}

private final class PrivateStubTodoEventUsecase: StubTodoEventUsecase {
    
    override var currentTodoEvents: AnyPublisher<[TodoEvent], Never> {
        return super.currentTodoEvents
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var didRemoveTodoWithParamsCallback: ((String, Bool) -> Void)?
    override func removeTodo(_ id: String, onlyThisTime: Bool) async throws {
        self.didRemoveTodoWithParamsCallback?(id, onlyThisTime)
    }
}
