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
    private var spyGoogleUsecase: PrivateGoogleCalendarUsecase!
    private var spyAppleUsecase: PrivateAppleCalendarUsecase!
    private var stubIntegrationUsecase: StubExternalCalendarIntegrationUsecase!
    private var stubLiveActivityUsecase: StubEventLiveActivityUsecase!
    private var spyRouter: SpyEventListCellEventHanleRouter!

    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyTodoUsecase = .init()
        self.spySchedleUsecase = .init()
        self.spyForemostUsecase = .init()
        self.spyGoogleUsecase = .init()
        self.spyAppleUsecase = .init()
        self.stubIntegrationUsecase = .init([])
        self.spyRouter = .init()
    }

    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyTodoUsecase = nil
        self.spySchedleUsecase = nil
        self.spyForemostUsecase = nil
        self.spyGoogleUsecase = nil
        self.spyAppleUsecase = nil
        self.stubIntegrationUsecase = nil
        self.stubLiveActivityUsecase = nil
        self.spyRouter = nil
    }

    private func makeViewModel(
        shouldFailDoneTodo: Bool = false,
        googleWritePermission: GoogleCalendar.EventWritePermission = .writable,
        appleShouldFailWrite: Bool = false,
        googleShouldFailWrite: Bool = false,
        shouldFailReauthenticate: Bool = false,
        registeredLiveActivityTarget: LiveActivityTarget? = nil,
        liveActivityStartError: (any Error)? = nil
    ) -> EventListCellEventHanleViewModelImple {

        self.spyTodoUsecase.shouldFailCompleteTodo = shouldFailDoneTodo
        self.spyGoogleUsecase.stubWritePermission = googleWritePermission
        self.spyAppleUsecase.shouldFailWrite = appleShouldFailWrite
        self.spyGoogleUsecase.shouldFailWrite = googleShouldFailWrite
        self.stubIntegrationUsecase.shouldFailReauthenticate = shouldFailReauthenticate
        self.stubLiveActivityUsecase = .init(registeredTarget: registeredLiveActivityTarget)
        self.stubLiveActivityUsecase.stubStartError = liveActivityStartError

        let liveActivityToggleViewModel = LiveActivityToggleViewModelImple(
            eventLiveActivityUsecase: self.stubLiveActivityUsecase
        )

        let viewModel = EventListCellEventHanleViewModelImple(
            todoEventUsecase: self.spyTodoUsecase,
            scheduleEventUsecase: self.spySchedleUsecase,
            foremostEventUsecase: self.spyForemostUsecase,
            googleCalendarUsecase: self.spyGoogleUsecase,
            appleCalendarUsecase: self.spyAppleUsecase,
            externalCalendarIntegrationUsecase: self.stubIntegrationUsecase,
            liveActivityToggleViewModel: liveActivityToggleViewModel
        )
        viewModel.router = self.spyRouter
        liveActivityToggleViewModel.router = self.spyRouter
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
    
    func testViewModel_whenSelectGoogleCalendarEvent_showDetail() {
        // given
        let viewModel = self.makeViewModel()
        let model = GoogleCalendarEventCellViewModel.dummy()

        // when
        viewModel.selectEvent(model)

        // then
        XCTAssertEqual(self.spyRouter.didRouteToGoogleEventDetailWithId, "google")
    }

    func testViewModel_whenSelectAppleCalendarEvent_routeToDetail() {
        // given
        let viewModel = self.makeViewModel()
        let model = AppleCalendarEventCellViewModel.dummy()

        // when
        viewModel.selectEvent(model)

        // then
        XCTAssertEqual(self.spyRouter.didRouteToAppleCalendarEventDetailWithId, "apple-event")
    }
    
    func testViewModel_routeToHolidayEventDetail() {
        // given
        let viewModel = self.makeViewModel()
        let timeZone = TimeZone(abbreviation: "KST")!
        let holiday = HolidayCalendarEvent(
            .init(uuid: "holiday", dateString: "2023-02-03", name: "dummy"), in: timeZone
        )!
        
        // when
        let model = HolidayEventCellViewModel(holiday)
        viewModel.selectEvent(model)
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToHolidayEventDetailWithId, "holiday")
    }
}


// MARK: - 외부 캘린더 셀 more actions

extension EventListCellEventHanleViewModelImpleTests {

    func testGoogleCell_moreActionsIsNil_whenCalendarIsNotWritable() {
        // given
        let model = GoogleCalendarEventCellViewModel.dummy(isWritable: false)

        // when
        let actions = model.moreActions

        // then
        XCTAssertNil(actions)
    }

    func testGoogleCell_removeActions_whenNotRepeating() {
        // given
        let model = GoogleCalendarEventCellViewModel.dummy(isWritable: true, recurringEventId: nil)

        // when
        let actions = model.moreActions

        // then
        XCTAssertEqual(actions?.removeActions, [.remove(scope: .all)])
    }

    func testGoogleCell_removeActions_whenRepeating() {
        // given
        let model = GoogleCalendarEventCellViewModel.dummy(isWritable: true, recurringEventId: "master-1")

        // when
        let actions = model.moreActions

        // then
        XCTAssertEqual(actions?.removeActions, [.remove(scope: .onlyThisTime), .remove(scope: .all)])
    }

    func testGoogleCell_basicActionsIsEmpty() {
        // given
        let model = GoogleCalendarEventCellViewModel.dummy(isWritable: true)

        // when
        let actions = model.moreActions

        // then
        XCTAssertEqual(actions?.basicActions, [])
    }

    func testAppleCell_moreActionsIsNil_whenCalendarIsNotWritable() {
        // given
        let model = AppleCalendarEventCellViewModel.dummy(isWritable: false)

        // when
        let actions = model.moreActions

        // then
        XCTAssertNil(actions)
    }

    func testAppleCell_removeActions_whenRepeating() {
        // given
        let model = AppleCalendarEventCellViewModel.dummy(isWritable: true, isRepeating: true)

        // when
        let actions = model.moreActions

        // then
        XCTAssertEqual(actions?.removeActions, [.remove(scope: .onlyThisTime), .remove(scope: .thisAndFuture)])
    }

    func testAppleCell_removeActions_whenNotRepeating() {
        // given
        let model = AppleCalendarEventCellViewModel.dummy(isWritable: true, isRepeating: false)

        // when
        let actions = model.moreActions

        // then
        XCTAssertEqual(actions?.removeActions, [.remove(scope: .all)])
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
            and expectOnlyThisTime: Bool,
            expectConfirmMessage: String
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
            XCTAssertEqual(self.spyRouter.didShowConfirmWith?.message, expectConfirmMessage)
        }
        // when + then
        let dummy = TodoEventCellViewModel("todo", name: "some")
        parameterizeTest(
            "todo event 삭제",
            dummy, .remove(scope: .all),
            expectRemovedId: "todo", and: false,
            expectConfirmMessage: R.String.calendarEventMoreActionRemoveMessage
        )
        parameterizeTest(
            "반복중인 todo event 이번 회차만 삭제",
            dummy, .remove(scope: .onlyThisTime),
            expectRemovedId: "todo", and: true,
            expectConfirmMessage: R.String.calendarEventMoreActionRemoveOnlyThistimeMessage
        )
    }

    func testViewModel_removeScheduleEvent() {
        // given
        func parameterizeTest(
            _ description: String,
            _ cellViewModel: ScheduleEventCellViewModel,
            _ action: EventListMoreAction,
            expectRemovedId: String,
            and expectOnlyThisTime: EventTime?,
            expectConfirmMessage: String
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
            XCTAssertEqual(self.spyRouter.didShowConfirmWith?.message, expectConfirmMessage)
        }
        // when + then
        let dummy = ScheduleEventCellViewModel("schedule", name: "name")
            |> \.eventTimeRawValue .~ .at(100)
        parameterizeTest(
            "schedule event 삭제",
            dummy, .remove(scope: .all),
            expectRemovedId: "schedule", and: nil,
            expectConfirmMessage: R.String.calendarEventMoreActionRemoveMessage
        )
        parameterizeTest(
            "반복중인 schedule event 이번 회차만 삭제",
            dummy, .remove(scope: .onlyThisTime),
            expectRemovedId: "schedule", and: .at(100),
            expectConfirmMessage: R.String.calendarEventMoreActionRemoveOnlyThistimeMessage
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
        expect.expectedFulfillmentCount = 2
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
    
    func testViewModel_whenToggleLiveActivityToRegister_afterConfirm_startActivity() {
        // given
        let expect = expectation(description: "미등록 상태에서 토글하면 확인 후 등록")
        let viewModel = self.makeViewModel()
        self.stubLiveActivityUsecase.didStartTargetCallback = { _ in expect.fulfill() }
        let cellViewModel = TodoEventCellViewModel("todo", name: "name")
            |> \.eventTimeRawValue .~ .at(100)

        // when
        viewModel.handleMoreAction(cellViewModel, .toggleLiveActivity(isRegistered: false))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.stubLiveActivityUsecase.didStartTarget, cellViewModel.liveActivityTarget)
        XCTAssertEqual(
            self.spyRouter.didShowConfirmWith?.message,
            "calendar::event::more_action:live_activity:register:confirm".localized()
        )
    }

    func testViewModel_whenToggleLiveActivityToRegister_whileOtherTargetRegistered_showReplaceConfirm() {
        // given
        let expect = expectation(description: "다른 이벤트가 등록된 상태에서 등록을 누르면 교체 확인 문구가 뜬다")
        let viewModel = self.makeViewModel(registeredLiveActivityTarget: .todo(id: "other-todo"))
        self.stubLiveActivityUsecase.didStartTargetCallback = { _ in expect.fulfill() }
        let cellViewModel = TodoEventCellViewModel("todo", name: "name")
            |> \.eventTimeRawValue .~ .at(100)

        // when
        viewModel.handleMoreAction(cellViewModel, .toggleLiveActivity(isRegistered: false))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(
            self.spyRouter.didShowConfirmWith?.message,
            "calendar::event::more_action:live_activity:replace:confirm".localized()
        )
    }

    func testViewModel_whenToggleLiveActivityToUnregister_afterConfirm_stopActivity() {
        // given
        let expect = expectation(description: "등록 상태에서 토글하면 확인 후 해제")
        let viewModel = self.makeViewModel()
        self.stubLiveActivityUsecase.didStopActivityCallback = { expect.fulfill() }
        let cellViewModel = TodoEventCellViewModel("todo", name: "name")
            |> \.eventTimeRawValue .~ .at(100)

        // when
        viewModel.handleMoreAction(cellViewModel, .toggleLiveActivity(isRegistered: true))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.stubLiveActivityUsecase.didStopActivity, true)
        XCTAssertNil(self.stubLiveActivityUsecase.didStartTarget)
        XCTAssertEqual(
            self.spyRouter.didShowConfirmWith?.message,
            "calendar::event::more_action:live_activity:unregister:confirm".localized()
        )
    }

    func testViewModel_whenStartLiveActivityFails_showUnavailableConfirm() {
        // given
        let expect = expectation(description: "등록 실패시 안내 다이얼로그 표시")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel(
            liveActivityStartError: EventLiveActivityStartFailReason.tooFarFuture
        )
        self.spyRouter.didShowConfirmWithCallback = { _ in expect.fulfill() }
        let cellViewModel = TodoEventCellViewModel("todo", name: "name")
            |> \.eventTimeRawValue .~ .at(100)

        // when
        viewModel.handleMoreAction(cellViewModel, .toggleLiveActivity(isRegistered: false))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.spyRouter.didShowConfirmWith?.withCancel, false)
    }

    func testViewModel_whenCancelToggleLiveActivityConfirm_doesNothing() {
        // given
        let viewModel = self.makeViewModel()
        self.spyRouter.shouldConfirmNotCancel = false
        let cellViewModel = TodoEventCellViewModel("todo", name: "name")
            |> \.eventTimeRawValue .~ .at(100)

        // when
        viewModel.handleMoreAction(cellViewModel, .toggleLiveActivity(isRegistered: false))

        // then
        XCTAssertNotNil(self.spyRouter.didShowConfirmWith)
        XCTAssertNil(self.stubLiveActivityUsecase.didStartTarget)
        XCTAssertEqual(self.stubLiveActivityUsecase.didStopActivity, false)
    }

    func testViewModel_whenCellHasNoLiveActivityTarget_toggleLiveActivityDoesNothing() {
        // given
        let viewModel = self.makeViewModel()
        let cellViewModel = TodoEventCellViewModel("todo", name: "name")

        // when
        viewModel.handleMoreAction(cellViewModel, .toggleLiveActivity(isRegistered: false))

        // then
        XCTAssertNil(self.spyRouter.didShowConfirmWith)
        XCTAssertNil(self.stubLiveActivityUsecase.didStartTarget)
    }


}


// MARK: - 외부 캘린더 이벤트 삭제

extension EventListCellEventHanleViewModelImpleTests {

    func testViewModel_whenRemoveGoogleEventOnlyThisTime_removeInstanceWithThisEventOnlyScope() {
        // given
        let expect = expectation(description: "구글 이벤트 이번 회차만 삭제")
        self.spyGoogleUsecase.didRemoveEventWithCallback = { expect.fulfill() }
        let viewModel = self.makeViewModel(googleWritePermission: .writable)
        let cellViewModel = GoogleCalendarEventCellViewModel.dummy(isWritable: true, recurringEventId: "master-1")

        // when
        viewModel.handleMoreAction(cellViewModel, .remove(scope: .onlyThisTime))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.spyGoogleUsecase.didRemoveEventWith?.eventId, "google")
        XCTAssertEqual(self.spyGoogleUsecase.didRemoveEventWith?.scope, .thisEventOnly)
    }

    func testViewModel_whenRemoveRepeatingGoogleEventWithAllScope_removeMasterWithAllEventsScope() {
        // given
        let expect = expectation(description: "구글 반복 이벤트 전체 삭제 — 시리즈 마스터 id 사용")
        self.spyGoogleUsecase.didRemoveEventWithCallback = { expect.fulfill() }
        let viewModel = self.makeViewModel(googleWritePermission: .writable)
        let cellViewModel = GoogleCalendarEventCellViewModel.dummy(isWritable: true, recurringEventId: "master-1")

        // when
        viewModel.handleMoreAction(cellViewModel, .remove(scope: .all))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.spyGoogleUsecase.didRemoveEventWith?.eventId, "master-1")
        XCTAssertEqual(self.spyGoogleUsecase.didRemoveEventWith?.scope, .allEvents)
    }

    func testViewModel_whenRemoveNotRepeatingGoogleEvent_removeItselfWithThisEventOnlyScope() {
        // given
        let expect = expectation(description: "구글 비반복 이벤트 전체 삭제 — 인스턴스 id 사용")
        self.spyGoogleUsecase.didRemoveEventWithCallback = { expect.fulfill() }
        let viewModel = self.makeViewModel(googleWritePermission: .writable)
        let cellViewModel = GoogleCalendarEventCellViewModel.dummy(isWritable: true, recurringEventId: nil)

        // when
        viewModel.handleMoreAction(cellViewModel, .remove(scope: .all))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.spyGoogleUsecase.didRemoveEventWith?.eventId, "google")
        XCTAssertEqual(self.spyGoogleUsecase.didRemoveEventWith?.scope, .thisEventOnly)
    }

    func testViewModel_whenRemoveGoogleEventAndNeedReauthentication_reauthenticateThenRemove() {
        // given
        let expect = expectation(description: "재인증 이후 삭제 실행")
        self.spyGoogleUsecase.didRemoveEventWithCallback = { expect.fulfill() }
        let viewModel = self.makeViewModel(googleWritePermission: .needReauthentication)
        let cellViewModel = GoogleCalendarEventCellViewModel.dummy(isWritable: true, recurringEventId: nil)

        // when
        viewModel.handleMoreAction(cellViewModel, .remove(scope: .all))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.stubIntegrationUsecase.didReauthenticateWith?.accountId, "stub@gmail.com")
        XCTAssertEqual(self.spyGoogleUsecase.didRemoveEventWith?.eventId, "google")
    }

    func testViewModel_whenRemoveGoogleEventAndReauthenticateFailed_showError() {
        // given
        let expect = expectation(description: "재인증 자체가 실패하면 에러 노출, 삭제는 시도 안 함")
        self.spyRouter.didShowErrorCallback = { _ in expect.fulfill() }
        let viewModel = self.makeViewModel(
            googleWritePermission: .needReauthentication, shouldFailReauthenticate: true
        )
        let cellViewModel = GoogleCalendarEventCellViewModel.dummy(isWritable: true, recurringEventId: nil)

        // when
        viewModel.handleMoreAction(cellViewModel, .remove(scope: .all))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertNotNil(self.spyRouter.didShowError)
        XCTAssertNil(self.spyGoogleUsecase.didRemoveEventWith)
    }

    func testViewModel_whenCancelReauthenticateConfirm_neitherReauthenticateNorRemove() {
        // given
        let notCalled = expectation(description: "재인증 확인 다이얼로그를 거절하면 재인증도 삭제도 시도 안 함")
        notCalled.isInverted = true
        self.spyGoogleUsecase.didRemoveEventWithCallback = { notCalled.fulfill() }
        let viewModel = self.makeViewModel(googleWritePermission: .needReauthentication)
        self.spyRouter.shouldConfirmNotCancel = false
        let cellViewModel = GoogleCalendarEventCellViewModel.dummy(isWritable: true, recurringEventId: nil)

        // when
        viewModel.handleMoreAction(cellViewModel, .remove(scope: .all))
        self.wait(for: [notCalled], timeout: 0.3)

        // then
        XCTAssertNil(self.stubIntegrationUsecase.didReauthenticateWith)
        XCTAssertNil(self.spyGoogleUsecase.didRemoveEventWith)
    }

    func testViewModel_whenRemoveGoogleEventFailed_showError() {
        // given
        let expect = expectation(description: "구글 삭제 자체가 실패하면 에러 노출")
        self.spyRouter.didShowErrorCallback = { _ in expect.fulfill() }
        let viewModel = self.makeViewModel(googleWritePermission: .writable, googleShouldFailWrite: true)
        let cellViewModel = GoogleCalendarEventCellViewModel.dummy(isWritable: true, recurringEventId: nil)

        // when
        viewModel.handleMoreAction(cellViewModel, .remove(scope: .all))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertNotNil(self.spyRouter.didShowError)
    }

    func testViewModel_whenRemoveGoogleEventOnReadOnlyCalendar_notRemove() {
        // given
        let notCalled = expectation(description: "읽기 전용 캘린더에서는 삭제도 확인 다이얼로그도 시도하지 않음")
        notCalled.isInverted = true
        self.spyGoogleUsecase.didRemoveEventWithCallback = { notCalled.fulfill() }
        let viewModel = self.makeViewModel(googleWritePermission: .readOnlyCalendar)
        let cellViewModel = GoogleCalendarEventCellViewModel.dummy(isWritable: true, recurringEventId: nil)

        // when
        viewModel.handleMoreAction(cellViewModel, .remove(scope: .all))
        self.wait(for: [notCalled], timeout: 0.3)

        // then
        XCTAssertNil(self.spyGoogleUsecase.didRemoveEventWith)
        XCTAssertNil(self.spyRouter.didShowConfirmWith)
    }

    func testViewModel_whenRemoveAppleEventOnlyThisTime_removeWithThisEventOnlyScope() {
        // given
        let expect = expectation(description: "애플 이벤트 이번만 삭제")
        self.spyAppleUsecase.didRemoveEventWithCallback = { expect.fulfill() }
        let viewModel = self.makeViewModel()
        let cellViewModel = AppleCalendarEventCellViewModel.dummy(isWritable: true, isRepeating: true)

        // when
        viewModel.handleMoreAction(cellViewModel, .remove(scope: .onlyThisTime))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.spyAppleUsecase.didRemoveEventWith?.eventId, "apple-event")
        XCTAssertEqual(self.spyAppleUsecase.didRemoveEventWith?.scope, .thisEventOnly)
    }

    func testViewModel_whenRemoveAppleEventThisAndFuture_removeWithThisAndFutureScope() {
        // given
        let expect = expectation(description: "애플 이벤트 이후 모든 이벤트 삭제")
        self.spyAppleUsecase.didRemoveEventWithCallback = { expect.fulfill() }
        let viewModel = self.makeViewModel()
        let cellViewModel = AppleCalendarEventCellViewModel.dummy(isWritable: true, isRepeating: true)

        // when
        viewModel.handleMoreAction(cellViewModel, .remove(scope: .thisAndFuture))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.spyAppleUsecase.didRemoveEventWith?.eventId, "apple-event")
        XCTAssertEqual(self.spyAppleUsecase.didRemoveEventWith?.scope, .thisAndFuture)
        XCTAssertEqual(
            self.spyRouter.didShowConfirmWith?.message,
            "calendar::event::more_action::remove_this_and_future:message".localized()
        )
    }

    func testViewModel_whenRemoveNotRepeatingAppleEventWithAllScope_removeWithThisEventOnlyScope() {
        // given
        let expect = expectation(description: "애플 비반복 이벤트를 all scope로 삭제해도 thisEventOnly로 변환")
        self.spyAppleUsecase.didRemoveEventWithCallback = { expect.fulfill() }
        let viewModel = self.makeViewModel()
        let cellViewModel = AppleCalendarEventCellViewModel.dummy(isWritable: true, isRepeating: false)

        // when
        viewModel.handleMoreAction(cellViewModel, .remove(scope: .all))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertEqual(self.spyAppleUsecase.didRemoveEventWith?.eventId, "apple-event")
        XCTAssertEqual(self.spyAppleUsecase.didRemoveEventWith?.scope, .thisEventOnly)
    }

    func testViewModel_whenRemoveExternalEventFailed_showError() {
        // given
        let expect = expectation(description: "삭제 실패시 에러 노출")
        self.spyRouter.didShowErrorCallback = { _ in expect.fulfill() }
        let viewModel = self.makeViewModel(appleShouldFailWrite: true)
        let cellViewModel = AppleCalendarEventCellViewModel.dummy(isWritable: true, isRepeating: false)

        // when
        viewModel.handleMoreAction(cellViewModel, .remove(scope: .all))
        self.wait(for: [expect], timeout: self.timeout)

        // then
        XCTAssertNotNil(self.spyRouter.didShowError)
    }
}

extension EventListCellEventHanleViewModelImpleTests {

    func testViewModel_makeTodoWithParams() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.eventDetail(copyFromTodo: .init(), detail: nil)
        
        // then
        let params = self.spyRouter.didRouteToMakeNewEventWithParams
        if case .todoWith = params?.makeSource {
            XCTAssert(true)
        } else {
            XCTFail("기대한 타입이 아님")
        }
    }
    
    func testViewModel_makeScheduleWithParams() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.eventDetail(copyFromSchedule: .init(), detail: nil)
        
        // then
        let params = self.spyRouter.didRouteToMakeNewEventWithParams
        if case .scheduleWith = params?.makeSource {
            XCTAssert(true)
        } else {
            XCTFail("기대한 타입이 아님")
        }
    }
    
    func testViewModel_copyTodoEventFromList() {
        // given
        let viewModel = self.makeViewModel()
        let todo = TodoEventCellViewModel("some", name: "origin")
        
        // when
        viewModel.handleMoreAction(todo, .copy)
        
        // then
        if case .todoFromCopy = self.spyRouter.didRouteToMakeNewEventWithParams?.makeSource {
            XCTAssert(true)
        } else {
            XCTFail("기대한 이벤트가 아님")
        }
    }
    
    func testViewModel_copyScheduleEventFromList() {
        // given
        let viewModel = self.makeViewModel()
        let schedule = ScheduleEventCellViewModel("some", name: "origin")
        
        // when
        viewModel.handleMoreAction(schedule, .copy)
        
        // then
        if case .scheduleFromCopy = self.spyRouter.didRouteToMakeNewEventWithParams?.makeSource {
            XCTAssert(true)
        } else {
            XCTFail("기대한 이벤트가 아님")
        }
    }
}

final class SpyEventListCellEventHanleRouter: BaseSpyRouter, EventListCellEventHanleRouting, @unchecked Sendable {
    
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
    
    var didRouteToHolidayEventDetailWithId: String?
    func routeToHolidayEventDetail(_ uuid: String) {
        self.didRouteToHolidayEventDetailWithId = uuid
    }
    
    var didRouteToGoogleEventDetailWithId: String?
    func routeToGoogleEventDetail(
        calendarId: String, accountId: String, eventId: String
    ) {
        self.didRouteToGoogleEventDetailWithId = eventId
    }
    
    var didRouteToAppleCalendarEventDetailWithId: String?
    func routeToAppleCalendarEventDetail(calendarId: String, eventId: String) {
        self.didRouteToAppleCalendarEventDetailWithId = eventId
    }
    
    var didRouteToMakeNewEventWithParams: MakeEventParams?
    func routeToMakeNewEvent(_ withParams: MakeEventParams) {
        self.didRouteToMakeNewEventWithParams = withParams
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
    
    override func skipRepeatingTodo(_ todoId: String) async throws -> TodoEvent {

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

private final class PrivateGoogleCalendarUsecase: StubGoogleCalendarUsecase {

    var didRemoveEventWithCallback: (() -> Void)?
    override func removeEvent(
        _ calendarId: String,
        _ eventId: String,
        accountId: String,
        scope: GoogleCalendar.EventRemoveScope
    ) async throws {
        try await super.removeEvent(calendarId, eventId, accountId: accountId, scope: scope)
        self.didRemoveEventWithCallback?()
    }
}

private final class PrivateAppleCalendarUsecase: StubAppleCalendarUsecase {

    var didRemoveEventWithCallback: (() -> Void)?
    override func removeEvent(
        _ eventId: String,
        scope: AppleCalendar.EventEditScope
    ) async throws {
        try await super.removeEvent(eventId, scope: scope)
        self.didRemoveEventWithCallback?()
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

extension GoogleCalendarEventCellViewModel {

    static func dummy(
        _ link: String? = "link",
        isWritable: Bool = false,
        recurringEventId: String? = nil
    ) -> GoogleCalendarEventCellViewModel {
        let google = GoogleCalendar.Event(
            "google", "calendar", accountId: "stub@gmail.com",
            name: "name",
            colorId: "id", htmlLink: link,
            time: .at(1)
        )
        |> \.recurringEventId .~ recurringEventId
        let googleEvent = GoogleCalendarEvent(google, in: TimeZone.current, isWritable: isWritable)
        return GoogleCalendarEventCellViewModel(
            googleEvent, in: 0..<10, TimeZone.current, true
        )!
    }
}

extension AppleCalendarEventCellViewModel {

    static func dummy(
        isWritable: Bool = false,
        isRepeating: Bool = false
    ) -> AppleCalendarEventCellViewModel {
        let appleEvent = AppleCalendar.Event(
            eventId: "apple-event",
            originalEventId: "apple-event",
            calendarId: "apple-calendar",
            name: "Apple Event",
            eventTime: .at(1)
        )
        |> \.isRepeating .~ isRepeating
        let calendarEvent = AppleCalendarEvent(appleEvent, in: TimeZone.current, isWritable: isWritable)
        return AppleCalendarEventCellViewModel(
            calendarEvent, in: 0..<10, TimeZone.current, true
        )!
    }
}
