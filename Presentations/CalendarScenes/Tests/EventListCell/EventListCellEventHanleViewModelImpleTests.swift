//
//  EventListCellEventHanleViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 6/28/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes
import UnitTestHelpKit
import TestDoubles

@testable import CalendarScenes

class EventListCellEventHanleViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyTodoUsecase: PrivateStubTodoEventUsecase!
    private var spySchedleUsecase: PrivateScheduleEventUsecase!
    private var spyForemostUsecase: PrivateForemostEventUsecase!
    private var spyRouter: SpyRouter!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyTodoUsecase = .init()
        self.spySchedleUsecase = .init()
        self.spyForemostUsecase = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyTodoUsecase = nil
        self.spySchedleUsecase = nil
        self.spyForemostUsecase = nil
        self.spyRouter = nil
    }
    
    private func makeViewModel(
        shouldFailDoneTodo: Bool = false
    ) -> EventListCellEventHanleViewModelImple {
        
        self.spyTodoUsecase.shouldFailCompleteTodo = shouldFailDoneTodo
        
        let viewModel = EventListCellEventHanleViewModelImple(
            todoEventUsecase: self.spyTodoUsecase,
            scheduleEventUsecase: self.spySchedleUsecase,
            foremostEventUsecase: self.spyForemostUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}


// MARK: - test handle select cell

extension EventListCellEventHanleViewModelImpleTests {
    
    func testViewModel_whenSelectTodoEvent_routeToTodoDetail() {
        // given
        let viewModel = self.makeViewModel()
        let timeZone = TimeZone(abbreviation: "KST")!
        let todo = TodoCalendarEvent(.init(uuid: "dummy", name: "some"), in: timeZone)
        // when
        let todoModel = TodoEventCellViewModel(todo, in: 0..<100, timeZone, true)!
        viewModel.selectEvent(todoModel)
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToTodoDetail, true)
    }
    
    func testViewModel_whenSelectScheduleEvent_routeToScheduleDetail() {
        // given
        let viewModel = self.makeViewModel()
        let timeZone = TimeZone(abbreviation: "KST")!
        let schedule = ScheduleCalendarEvent(
            eventIdWithoutTurn: "ev",
            eventId: "dummy",
            name: "some",
            eventTime: .at(0),
            eventTimeOnCalendar: .at(0),
            eventTagId: .default,
            isRepeating: false
        )

        // when
        let model = ScheduleEventCellViewModel(schedule, in: 0..<10, timeZone: timeZone, true)!
        viewModel.selectEvent(model)

        // then
        XCTAssertEqual(self.spyRouter.didRouteToScheduleDetail, true)
    }
    
    func testViewModel_whenSelectHolidayEvent_showNotSupportToast() {
        // given
        let viewModel = self.makeViewModel()
        let timeZone = TimeZone(abbreviation: "KST")!
        let holiday = HolidayCalendarEvent(
            .init(dateString: "2023-02-03", localName: "dummy", name: "dummy"), in: timeZone
        )!
        
        // when
        let model = HolidayEventCellViewModel(holiday)
        viewModel.selectEvent(model)
        
        // then
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.notSupport::holiday".localized())
    }
}


// MARK: - test handle done todo

extension EventListCellEventHanleViewModelImpleTests {
    
    func testViewModel_doneTodo() {
        // given
        func parameterizeTest(shouldFail: Bool) {
            // given
            let expect = expectation(description: "wait done result")
            let viewModel = self.makeViewModel(shouldFailDoneTodo: shouldFail)
            
            // when
            let result = self.waitFirstOutput(expect, for: viewModel.doneTodoResult, timeout: 0.1) {
                viewModel.doneTodo("some")
            }
            
            // then
            XCTAssertEqual(result?.isSuccess, !shouldFail)
            XCTAssertEqual(self.spyRouter.didShowError == nil, !shouldFail)
        }
        // when + then
        parameterizeTest(shouldFail: false)
        parameterizeTest(shouldFail: true)
    }
        
    func testViewModel_cancelCompleteTodo() {
        // given
        let expect = expectation(description: "todo 완료 이벤트 처리 취소")
        let viewModel = self.makeViewModel()
        self.spyTodoUsecase.completeTodoHasLatency = true

        // when
        let result = self.waitFirstOutput(expect, for: viewModel.doneTodoResult, timeout: 0.1) {
            viewModel.doneTodo("current-todo-2")
            viewModel.cancelDoneTodo("current-todo-2")
        }

        // then
        XCTAssertEqual(result?.failedReason is CancellationError, true)
        XCTAssertEqual(self.spyRouter.didShowError == nil, true)
    }
}


// MARK: - test handle more action

extension EventListCellEventHanleViewModelImpleTests {
    
    func testViewModel_removeTodoEvent() {
        // given
        func parameterizeTest(
            _ description: String,
            _ cellViewModel: TodoEventCellViewModel,
            _ action: EventListMoreAction,
            expectRemovedId: String,
            and expectOnlyThisTime: Bool
        ) {
            // given
            let expect = expectation(description: description)
            let viewModel = self.makeViewModel()
            var recordParams: (String, Bool)?
            self.spyTodoUsecase.didRemoveTodoWithParamsCallback = {
                recordParams = ($0, $1)
                expect.fulfill()
            }

            // when
            viewModel.handleMoreAction(cellViewModel, action)
            self.wait(for: [expect], timeout: self.timeout)

            // then
            XCTAssertEqual(recordParams?.0, expectRemovedId)
            XCTAssertEqual(recordParams?.1, expectOnlyThisTime)
            XCTAssertEqual(self.spyRouter.didShowConfirmWith != nil, true)
        }
        // when + then
        let dummy = TodoEventCellViewModel("todo", name: "some")
        parameterizeTest(
            "todo event 삭제",
            dummy, .remove(onlyThisTime: false),
            expectRemovedId: "todo", and: false
        )
        parameterizeTest(
            "반복중인 todo event 이번 회차만 삭제",
            dummy, .remove(onlyThisTime: true),
            expectRemovedId: "todo", and: true
        )
    }
    
    func testViewModel_removeScheduleEvent() {
        // given
        func parameterizeTest(
            _ description: String,
            _ cellViewModel: ScheduleEventCellViewModel,
            _ action: EventListMoreAction,
            expectRemovedId: String,
            and expectOnlyThisTime: EventTime?
        ) {
            // given
            let expect = expectation(description: description)
            let viewModel = self.makeViewModel()
            var recordParams: (String, EventTime?)?
            self.spySchedleUsecase.didRemoveEventWithParamsCallback = {
                recordParams = ($0, $1)
                expect.fulfill()
            }

            // when
            viewModel.handleMoreAction(cellViewModel, action)
            self.wait(for: [expect], timeout: self.timeout)

            // then
            XCTAssertEqual(recordParams?.0, expectRemovedId)
            XCTAssertEqual(recordParams?.1, expectOnlyThisTime)
            XCTAssertEqual(self.spyRouter.didShowConfirmWith != nil, true)
        }
        // when + then
        let dummy = ScheduleEventCellViewModel("schedule", name: "name")
            |> \.eventTimeRawValue .~ .at(100)
        parameterizeTest(
            "schedule event 삭제",
            dummy, .remove(onlyThisTime: false),
            expectRemovedId: "schedule", and: nil
        )
        parameterizeTest(
            "반복중인 schedule event 이번 회차만 삭제",
            dummy, .remove(onlyThisTime: true),
            expectRemovedId: "schedule", and: .at(100)
        )
    }
    
    func testViewModel_toggleIsForemostEvent() {
        // given
        enum ExpectedRecord: Equatable {
            case removed
            case updated(ForemostEventId)
        }
        func parameterizeTest(
            _ description: String,
            _ cellViewModel: any EventCellViewModel,
            _ action: EventListMoreAction,
            expectRecordedValue: ExpectedRecord
        ) {
            // given
            let expect = expectation(description: description)
            var recorded: ExpectedRecord?
            let viewModel = self.makeViewModel()
            switch expectRecordedValue {
            case .updated:
                self.spyForemostUsecase.didUpdateForemostCallback = {
                    recorded = .updated($0)
                    expect.fulfill()
                }
            case .removed:
                self.spyForemostUsecase.didRemoveForemostCallback = {
                    recorded = .removed
                    expect.fulfill()
                }
            }

            // when
            viewModel.handleMoreAction(cellViewModel, action)
            self.wait(for: [expect], timeout: self.timeout)

            // then
            XCTAssertEqual(recorded, expectRecordedValue)
            XCTAssertEqual(self.spyRouter.didShowConfirmWith != nil, true)
        }

        // when + then
        let todo = TodoEventCellViewModel("todo", name: "name")
        parameterizeTest(
            "foremost 이벤트로 todo 등록",
            todo,
            .toggleTo(isForemost: true),
            expectRecordedValue: .updated(.init("todo", true))
        )
        parameterizeTest(
            "foremost 이벤트로 todo 등록 해제",
            todo,
            .toggleTo(isForemost: false),
            expectRecordedValue: .removed
        )
        let schedule = ScheduleEventCellViewModel("schedule", name: "name")
        parameterizeTest(
            "foremost 이벤트로 schedule 등록",
            schedule,
            .toggleTo(isForemost: true),
            expectRecordedValue: .updated(.init("schedule", false))
        )
        parameterizeTest(
            "foremost 이벤트로 schedule 등록 해제",
            schedule,
            .toggleTo(isForemost: false),
            expectRecordedValue: .removed
        )
    }
    
    func testViewModel_whenTryToMarkRepeatingScheduleEventAsForemostEvent_showNotSupports() {
        // given
        let expect = expectation(description: "반복되는 일정을 제일중요 이벤트로 등록하려 하는 경우 불가함을 알림")
        let viewModel = self.makeViewModel()
        var confirmWith: ConfirmDialogInfo?
        self.spyRouter.didShowConfirmWithCallback = { info in
            confirmWith = info
            expect.fulfill()
        }
        
        // when
        let cellViewModel = ScheduleEventCellViewModel(
            "repeating-schedule", turn: 2, name: "schedule", isRepeating: true
        )
        viewModel.handleMoreAction(cellViewModel, .toggleTo(isForemost: true))
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        let message = confirmWith?.message
        XCTAssertEqual(
            message, "calendar::event::more_action::mark_as_foremost::unavail".localized()
        )
    }
    
    func testViewModel_skipRepeatingTodo() {
        // given
        let expect = expectation(description: "다음차수로 todo skip")
        let dummyId = "some"
        let viewModel = self.makeViewModel()
        let todo = TodoEventCellViewModel(dummyId, name: "origin")
        
        // when
        let todos = self.waitOutputs(expect, for: self.spyTodoUsecase.todoEvent(dummyId)) {
            viewModel.handleMoreAction(todo, .skipTodo)
        }
        
        // then
        let names = todos.map { $0.name }
        XCTAssertEqual(names, ["origin", "skipped"])
    }
}

private final class SpyRouter: BaseSpyRouter, EventListCellEventHanleRouting, @unchecked Sendable {
    
    func attach(_ scene: any Scene) { }
    
    var didRouteToTodoDetail: Bool?
    func routeToTodoEventDetail(_ eventId: String) {
        self.didRouteToTodoDetail = true
    }
    
    var didRouteToScheduleDetail: Bool?
    var didRouteToScheduleDetailWithTargetTime: EventTime?
    func routeToScheduleEventDetail(
        _ eventId: String,
        _ repeatingEventTargetTime: EventTime?
    ) {
        self.didRouteToScheduleDetail = true
        self.didRouteToScheduleDetailWithTargetTime = repeatingEventTargetTime
    }
}

private final class PrivateStubTodoEventUsecase: StubTodoEventUsecase {
    
    var completeTodoHasLatency: Bool = false
    
    override func completeTodo(_ eventId: String) async throws -> DoneTodoEvent {
        if completeTodoHasLatency {
            try await Task.sleep(for: .milliseconds(10))
        }
        try Task.checkCancellation()
        return try await super.completeTodo(eventId)
    }
    
    var didRemoveTodoWithParamsCallback: ((String, Bool) -> Void)?
    override func removeTodo(_ id: String, onlyThisTime: Bool) async throws {
        self.didRemoveTodoWithParamsCallback?(id, onlyThisTime)
    }
    
    private let fakeTodo = CurrentValueSubject<TodoEvent, Never>(TodoEvent(uuid: "some", name: "origin"))
    override func todoEvent(_ id: String) -> AnyPublisher<TodoEvent, any Error> {
        return fakeTodo
            .mapNever()
            .eraseToAnyPublisher()
    }
    
    override func skipRepeatingTodo(_ todoId: String, _ params: SkipTodoParams) async throws -> TodoEvent {
        
        let newTodo = TodoEvent(uuid: todoId, name: "skipped")
        self.fakeTodo.send(newTodo)
        return newTodo
    }
}

private final class PrivateScheduleEventUsecase: StubScheduleEventUsecase {
    
    var didRemoveEventWithParamsCallback: ((String, EventTime?) -> Void)?
    override func removeScheduleEvent(_ eventId: String, onlyThisTime: EventTime?) async throws {
        self.didRemoveEventWithParamsCallback?(eventId, onlyThisTime)
    }
}

private final class PrivateForemostEventUsecase: StubForemostEventUsecase {
    
    var didUpdateForemostCallback: ((ForemostEventId) -> Void)?
    override func update(foremost eventId: ForemostEventId) async throws {
        self.didUpdateForemostCallback?(eventId)
        try await super.update(foremost: eventId)
    }
    
    var didRemoveForemostCallback: (() -> Void)?
    override func remove() async throws {
        self.didRemoveForemostCallback?()
        try await super.remove()
    }
}

private extension DoneTodoResult {
    
    var isSuccess: Bool {
        guard case .success = self else { return false }
        return true
    }
    
    var failedReason: (any Error)? {
        guard case let .failed(_, reason) = self else { return nil }
        return reason
    }
}
