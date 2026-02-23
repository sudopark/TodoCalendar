//
//  EditScheduleEventDetailViewModelImpleTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 11/12/23.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Scenes
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene


class EditScheduleEventDetailViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyScheduleUsecase: PrivateStubScheduleEventUsecase!
    private var spyEventDetailDataUsecase: StubEventDetailDataUsecase!
    private var stubForemostEventUsecase: StubForemostEventUsecase!
    private var spyRouter: SpyEventDetailRouter!
    private var spyListener: SpyEventDetailListener!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyScheduleUsecase = .init()
        self.spyEventDetailDataUsecase = .init()
        self.spyRouter = .init()
        self.spyListener = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyScheduleUsecase = nil
        self.spyEventDetailDataUsecase = nil
        self.stubForemostEventUsecase = nil
        self.spyRouter = nil
        self.spyListener = nil
    }
    
    private var timeZone: TimeZone {
        return TimeZone(abbreviation: "KST")!
    }
    
    private func makeViewModel(
        customSchedule: ScheduleEvent? = nil,
        repeatingEventTargetTime: EventTime? = nil,
        shouldFailSave: Bool = false,
        isForemost: Bool = false,
        shouldFailToTransformToTodo: Bool = false,
        shouldFailToSaveDetail: Bool = false,
        shouldFailToRemoveSchedule: Bool = false
    ) -> EditScheduleEventDetailViewModelImple {
        
        let (schedule, detail) = (customSchedule ?? self.dummyRepeatingSchedule, self.dummyDetail)
        self.spyScheduleUsecase.stubEvent = schedule
        self.spyEventDetailDataUsecase.stubDetail = detail
        self.spyEventDetailDataUsecase.shouldFailSaveDetail = shouldFailToSaveDetail
        self.spyScheduleUsecase.shouldUpdateEventFail = shouldFailSave
        self.spyScheduleUsecase.shouldFailRemoveSchedule = shouldFailToRemoveSchedule
        
        let tagUsecase = StubEventTagUsecase()
        
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.selectTimeZone(self.timeZone)
        
        self.stubForemostEventUsecase = .init(
            foremostId: isForemost ? .init(event: schedule) : nil
        )
        self.stubForemostEventUsecase.refresh()
        
        let todoUsecase = StubTodoEventUsecase()
        todoUsecase.shouldFailMakeTodo = shouldFailToTransformToTodo
        
        let viewModel = EditScheduleEventDetailViewModelImple(
            scheduleId: schedule.uuid,
            repeatingEventTargetTime: repeatingEventTargetTime,
            scheduleUsecase: self.spyScheduleUsecase,
            eventTagUsecase: tagUsecase,
            eventDetailDataUsecase: self.spyEventDetailDataUsecase,
            todoEventUsecase: todoUsecase,
            calendarSettingUsecase: calendarSettingUsecase,
            foremostEventUsecase: self.stubForemostEventUsecase
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListener
        viewModel.attachInput()
        return viewModel
    }
    
    private var dummyRepeating: EventRepeating {
        return EventRepeating(
            repeatingStartTime: 0, repeatOption: EventRepeatingOptions.EveryDay()
        ) |> \.repeatingEndOption .~ .until(100)
    }
    
    private var dummyRepeatingSchedule: ScheduleEvent {
        return ScheduleEvent(uuid: "dummy_schedule", name: "dummy", time: .at(0))
        |> \.repeating .~ pure(self.dummyRepeating)
        |> \.eventTagId .~ .custom("tag")
        |> \.notificationOptions .~ [.atTime]
    }
    
    private var dummyDetail: EventDetailData {
        return EventDetailData("dummy_schedule")
        |> \.url .~ "url"
        |> \.memo .~ "memo"
    }
    
    private var dummyInvalidSelectTime: SelectedTime {
        let start = SelectTimeText(100, self.timeZone)
        let end = SelectTimeText(99, self.timeZone)
        return SelectedTime.period(start, end)
    }
}


// MARK: - test initail data

extension EditScheduleEventDetailViewModelImpleTests {
    
    func testViewModel_whenPrepare_showLoading() {
        // given
        let expect = expectation(description: "prepare 시에는 로딩중 표시")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isLoadings = self.waitOutputs(expect, for: viewModel.isLoading) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(isLoadings, [false, true, false])
    }
    
    // prepare 완료 이후 inputScene으로 초기 데이터 전달
    func testViewModel_whenAfterPrepare_sendDataToInputInteractor() {
        // given
        let expect = expectation(description: "prepare 완료 이후 inputScene으로 초기 데이터 전달")
        self.spyRouter.spyInteractor.didPreparedCallback = { expect.fulfill() }
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.prepare()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        let preparedWith = self.spyRouter.spyInteractor.didPreparedWith
        XCTAssertEqual(preparedWith?.0.name, self.dummyRepeatingSchedule.name)
        XCTAssertEqual(preparedWith?.0.selectedTime, .init(self.dummyRepeatingSchedule.time, self.timeZone))
        XCTAssertEqual(preparedWith?.0.eventRepeating, .init(self.dummyRepeating, timeZone: self.timeZone))
        XCTAssertEqual(preparedWith?.0.eventTagId, .custom("tag"))
        XCTAssertEqual(preparedWith?.0.eventNotifications, [.atTime])
        XCTAssertEqual(preparedWith?.1, self.dummyDetail)
    }
    
    func testViewModel_whenRepeatingEventTimeSelected_sendItAsEventDetail() {
        // given
        let expect = expectation(description: "prepare시에 반복이벤트 선택된 시간 지정된경우 해당값 전달")
        self.spyRouter.spyInteractor.didPreparedCallback = { expect.fulfill() }
        let viewModel = self.makeViewModel(repeatingEventTargetTime: .at(100))
        
        // when
        viewModel.prepare()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        let preparedWith = self.spyRouter.spyInteractor.didPreparedWith
        XCTAssertEqual(preparedWith?.0.selectedTime, .init(.at(100), self.timeZone))
    }
    
    func testViewModel_provideIsForemost() {
        // given
        let expect = expectation(description: "foremost 여부 제공")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isForemosts = self.waitOutputs(expect, for: viewModel.isForemost, timeout: 0.01) {
            Task {
                try await self.stubForemostEventUsecase.update(
                    foremost: .init("dummy_schedule", false)
                )
                
                try await self.stubForemostEventUsecase.update(
                    foremost: .init("another_schedule", false)
                )
            }
        }
        
        // then
        XCTAssertEqual(isForemosts, [false, true, false])
    }
    
    // isTodo == false + isTodoOrScheduleTogglable == false
    func testViewModel_isTodoAndIsTodoOrScheduleNotTogglable() {
        // given
        let expect = expectation(description: " isTodo == false + isTodoOrScheduleTogglable == false")
        let viewModel = self.makeViewModel()
        
        // when
        let typeModel = self.waitFirstOutput(expect, for: viewModel.eventDetailTypeModel)
        
        // then
        XCTAssertEqual(typeModel, EventDetailTypeModel.scheduleCase())
    }
    
    func testViewModel_provideEventDetailMoreActions() {
        // given
        func parameterizeTest(
            _ viewModel: EditScheduleEventDetailViewModelImple,
            expect expectingActions: [[EventDetailMoreAction]]
        ) {
            // given
            let expect = expectation(description: "wait more action")
            // when
            let actions = self.waitFirstOutput(expect, for: viewModel.moreActions) {
                viewModel.prepare()
            }
            
            // then
            XCTAssertEqual(actions, expectingActions)
        }
        // when + then
        let schedule = self.dummyRepeatingSchedule
        parameterizeTest(
            self.makeViewModel(customSchedule: schedule),
            expect: [
                [.remove(onlyThisEvent: true), .remove(onlyThisEvent: false)],
                [.copy, .transformToTodo]
            ]
        )
        parameterizeTest(
            self.makeViewModel(customSchedule: schedule, isForemost: true),
            expect: [
                [.remove(onlyThisEvent: true), .remove(onlyThisEvent: false)],
                [.copy, .transformToTodo]
            ]
        )
        let scheduleNotRepeating = schedule |> \.repeating .~ nil
        parameterizeTest(
            self.makeViewModel(customSchedule: scheduleNotRepeating),
            expect: [
                [.remove(onlyThisEvent: false)], 
                [.toggleTo(isForemost: true), .copy, .transformToTodo]
            ]
        )
        parameterizeTest(
            self.makeViewModel(customSchedule: scheduleNotRepeating, isForemost: true),
            expect: [
                [.remove(onlyThisEvent: false)],
                [.toggleTo(isForemost: false), .copy, .transformToTodo]
            ]
        )
    }
    
    func testViewModel_whenAfterRemoveSchedule_closeScene() {
        // given
        let expect = expectation(description: "Schedule 삭제 이후에 화면 닫음")
        self.spyRouter.didCloseCallback = { expect.fulfill() }
        let viewModel = self.makeViewModelWithPrepare()
        
        // when
        viewModel.handleMoreAction(.remove(onlyThisEvent: true))
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.scheduleEvent_removed::message".localized())
    }
    
    func testViewModel_toggleForemost() {
        // given
        let expect = expectation(description: "foremost 토글")
        expect.expectedFulfillmentCount = 2
        let scheduleNotRepeating = self.dummyRepeatingSchedule |> \.repeating .~ nil
        let viewModel = self.makeViewModel(customSchedule: scheduleNotRepeating)
        
        // when
        let isForemosts = self.waitOutputs(expect, for: viewModel.isForemost) {
            viewModel.handleMoreAction(.toggleTo(isForemost: true))
        }
        
        // then
        XCTAssertEqual(isForemosts, [false, true])
    }
    
    func testViewModel_whenCopyEvent_closeAndNotify() {
        // given
        let expect = expectation(description: "이벤트 복사시에 화면 닫고, 복사 요청")
        let viewModel = self.makeViewModelWithPrepare()
        self.spyListener.didCopyCallback = { expect.fulfill() }
        
        // when
        viewModel.handleMoreAction(.copy)
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(self.spyRouter.didClosed, true)
        let pair = self.spyListener.didRequestCopyFromSchedule
        XCTAssertEqual(pair?.0.name, self.dummyRepeatingSchedule.name)
        XCTAssertEqual(pair?.0.eventTagId, self.dummyRepeatingSchedule.eventTagId)
        XCTAssertEqual(pair?.0.time, self.dummyRepeatingSchedule.time)
        XCTAssertEqual(pair?.0.repeating, self.dummyRepeatingSchedule.repeating)
        XCTAssertEqual(pair?.0.notificationOptions, self.dummyRepeatingSchedule.notificationOptions)
        XCTAssertEqual(pair?.1, self.dummyDetail)
    }
    
    func testViewModel_transfromEventToTodo() {
        // given
        let expect = expectation(description: "schedule -> todo로 변환")
        let viewModel = self.makeViewModelWithPrepare()
        self.spyListener.didTransformedCallback = { expect.fulfill() }
        
        // when
        viewModel.handleMoreAction(.transformToTodo)
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        let dummyId = dummyRepeatingSchedule.uuid
        XCTAssertEqual(self.spyRouter.didShowConfirmWith?.title, "eventDetail.todoEvent::transform::schedule_title".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        XCTAssertEqual(self.spyListener.didSchduleTransformToTodo != nil, true)
        XCTAssertEqual(self.spyScheduleUsecase.didRemoveScheduleId, dummyId)
        XCTAssertEqual(self.spyScheduleUsecase.didRemoveScheduleOnlyThisTime, dummyRepeatingSchedule.time)
        XCTAssertNotNil(self.spyEventDetailDataUsecase.savedDetail)
        XCTAssertNotEqual(self.spyEventDetailDataUsecase.savedDetail?.eventId, dummyId)
        XCTAssertEqual(self.spyEventDetailDataUsecase.didRemovedDetailId, dummyId)
    }
    
    func testViewModel_transformToTodo_notRepeatingEvent() {
        // given
        let expect = expectation(description: "반복하지 않는 schedule -> todo로 변환")
        let viewModel = self.makeViewModelWithPrepare(isNotRepeating: true)
        self.spyListener.didTransformedCallback = { expect.fulfill() }
        
        // when
        viewModel.handleMoreAction(.transformToTodo)
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        let dummyId = dummyRepeatingSchedule.uuid
        XCTAssertEqual(self.spyRouter.didShowConfirmWith?.title, "eventDetail.todoEvent::transform::schedule_title".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        XCTAssertEqual(self.spyListener.didSchduleTransformToTodo != nil, true)
        XCTAssertEqual(self.spyScheduleUsecase.didRemoveScheduleId, dummyId)
        XCTAssertEqual(self.spyScheduleUsecase.didRemoveScheduleOnlyThisTime, nil)
        XCTAssertNotNil(self.spyEventDetailDataUsecase.savedDetail)
        XCTAssertNotEqual(self.spyEventDetailDataUsecase.savedDetail?.eventId, dummyId)
        XCTAssertEqual(self.spyEventDetailDataUsecase.didRemovedDetailId, dummyId)
    }
    
    // 전환중에는 로딩 표시
    func testViewModel_whenTransformToTodo_updateIsSaving() {
        // given
        let expect = expectation(description: "schedule -> todo 전환시에는 전환중임을 표시")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare()
        
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            
            viewModel.handleMoreAction(.transformToTodo)
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
    }
    
    // 이름 없으면 에러
    func testViewModel_whenTransformToTodoWithoutName_showIsNeed() {
        // given
        let viewModel = self.makeViewModelWithPrepare()
        let detail = EventDetailBasicData()
        viewModel.eventDetail(didInput: detail, additional: .init(self.dummyRepeatingSchedule.uuid))
        
        // when
        viewModel.handleMoreAction(.transformToTodo)
        
        // then
        XCTAssertEqual(
            self.spyRouter.didShowToastWithMessage,
            "eventDetail.unavailto_transform_withoutName".localized()
        )
    }
    
    // schedule 변환 실패했으면 실패
    func testViewModel_whenTransformTodoFails_showError() {
        // given
        let expect = expectation(description: "todo 변환 실패했으면 에러 노출 및 로딩중 표시 초기화")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare(
            shouldFailToTransformToTodo: true
        )
        
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving, timeout: 0.1) {
            viewModel.handleMoreAction(.transformToTodo)
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowError != nil, true)
    }
    
    // 디테일 저장 실패했으면 무시
    func testViewModel_whenTransformToTodoAndFailToSaveDetail_ignore() {
        // given
        let expect = expectation(description: "todo 전환시에 이벤트 상세 저장 실패해도 무시")
        self.spyListener.didTransformedCallback = { expect.fulfill() }
        let viewModel = self.makeViewModelWithPrepare(
            shouldFailToSaveDetail: true
        )
        
        // when
        viewModel.handleMoreAction(.transformToTodo)
        
        // then
        self.wait(for: [expect], timeout: self.timeoutLong)
    }
    
    // 전환하고 삭제 실패했어도 무시
    func testViewModel_whenTransformToTodoAndFailToRemoveTodo_ignore() {
        // given
        let expect = expectation(description: "todo 전환시에 todo 삭제 실패해도 무시")
        self.spyListener.didTransformedCallback = { expect.fulfill() }
        let viewModel = self.makeViewModelWithPrepare(
            shouldFailToRemoveSchedule: true
        )
        
        // when
        viewModel.handleMoreAction(.transformToTodo)
        
        // then
        self.wait(for: [expect], timeout: self.timeoutLong)
    }
}


// MARK: - test save changes

extension EditScheduleEventDetailViewModelImpleTests {
    
    private func makeViewModelWithPrepare(
        isNotRepeating: Bool = false,
        shouldFailEdit: Bool = false,
        repeatingEventTargetTime: EventTime? = nil,
        shouldFailToTransformToTodo: Bool = false,
        shouldFailToSaveDetail: Bool = false,
        shouldFailToRemoveSchedule: Bool = false
    ) -> EditScheduleEventDetailViewModelImple {
        // given
        let expect = expectation(description: "wait prepared")
        expect.expectedFulfillmentCount = 3
        
        let schedule = if isNotRepeating {
            self.dummyRepeatingSchedule |> \.repeating .~ nil
        } else {
            self.dummyRepeatingSchedule
        }
        let viewModel = self.makeViewModel(
            customSchedule: schedule,
            repeatingEventTargetTime: repeatingEventTargetTime,
            shouldFailSave: shouldFailEdit,
            shouldFailToTransformToTodo: shouldFailToTransformToTodo,
            shouldFailToSaveDetail: shouldFailToSaveDetail,
            shouldFailToRemoveSchedule: shouldFailToRemoveSchedule
        )
        
        // when
        let _ = self.waitOutputs(expect, for: viewModel.isLoading) {
            viewModel.prepare()
        }
        
        // then
        return viewModel
    }
    
    private func enter(
        _ viewModel: EditScheduleEventDetailViewModelImple,
        _ schedule: ScheduleEvent? = nil,
        basic: (EventDetailBasicData) -> EventDetailBasicData,
        detaiil: (EventDetailData) -> EventDetailData = { $0 }
    ) {
        let schedule = schedule ?? self.dummyRepeatingSchedule
        let oldBasic = EventDetailBasicData(
            name: schedule.name,
            eventTagId: schedule.eventTagId ?? .default
        )
        |> \.originEventTime .~ schedule.time
        |> \.selectedTime .~ .init(schedule.time, self.timeZone)
        |> \.eventRepeating .~ schedule.repeating.flatMap { .init($0, timeZone: self.timeZone) }
        |> \.eventNotifications .~ schedule.notificationOptions
        let newBasic = basic(oldBasic)
        let newDetail = detaiil(self.dummyDetail)
        viewModel.eventDetail(didInput: newBasic, additional: newDetail)
    }
    
    // name + time 있으면 저장 가능해짐
    func testViewModel_whenEnterName_isSavabla() {
        // given
        let expect = expectation(description: "name이 있고 선택시간이 유효하면 저장 가능해짐")
        expect.expectedFulfillmentCount = 7
        let viewModel = self.makeViewModelWithPrepare()
        
        // when
        let isSavables = self.waitOutputs(expect, for: viewModel.isSavable) {
            self.enter(viewModel) {
                $0 |> \.name .~ nil
            }
            self.enter(viewModel) {
                $0 |> \.name .~ "new name"
            }
            self.enter(viewModel) {
                $0 |> \.name .~ ""
            }
            self.enter(viewModel) {
                $0 |> \.name .~ "new name"
            }
            self.enter(viewModel) {
                $0 |> \.selectedTime .~ self.dummyInvalidSelectTime
            }
            self.enter(viewModel) {
                $0 |> \.selectedTime .~ .at(.init(1, self.timeZone))
            }
        }
        
        // then
        XCTAssertEqual(isSavables, [true, false, true, false, true, false, true])
    }
    
    func testViewModel_updateHasChangesByInput() {
        // given
        let expect = expectation(description: "입력여부 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare()
        
        // when
        let hasChanges = self.waitOutputs(expect, for: viewModel.hasChanges) {
            self.enter(viewModel) { $0 |> \.name .~ "edited" }
            self.enter(viewModel) { $0 |> \.name .~ "dummy" }
        }
        
        // then
        XCTAssertEqual(hasChanges, [false, true, false])
    }
    
    // 변경사항이 없는경우 저장시 바로 완료
    func testViewModel_whenHasNoChangesAndRequestSave_justClose() {
        // given
        let expect = expectation(description: "변경사항이 없는경우 저장시 바로 완료")
        let viewModel = self.makeViewModelWithPrepare()
        self.spyRouter.didCloseCallback = { expect.fulfill() }
        
        // when
        viewModel.save()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
        XCTAssertEqual(self.spyScheduleUsecase.didUpdateEditParams, nil)
        XCTAssertEqual(self.spyEventDetailDataUsecase.savedDetail, nil)
    }
    
    // 비 반복 이벤트의 경우 변경사항 저장 - 기본정보 저장하고, detail도 저장
    func testViewModel_whenNotRpeatingSchedule_saveTodoAndDetail() {
        // given
        let expect = expectation(description: "비 반복 이벤트 였던 경우 todo, detail 저장")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare(isNotRepeating: true)
        
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            self.enter(viewModel) {
                $0
                |> \.name .~ "new_name"
                |> \.selectedTime .~ pure(SelectedTime(.at(100), self.timeZone))
                |> \.eventRepeating .~ .init(self.dummyRepeating, timeZone: self.timeZone)
                |> \.eventTagId .~ .default
                |> \.eventNotifications .~ [.atTime]
                
            } detaiil: {
                $0 |> \.memo .~ "new_memo"
                    |> \.url .~ "new_url"
            }
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.scheduleEvent_saved::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let updateParams = self.spyScheduleUsecase.didUpdateEditParams
        XCTAssertEqual(updateParams?.name, "new_name")
        XCTAssertEqual(updateParams?.eventTagId, .default)
        XCTAssertEqual(updateParams?.time, .at(100))
        XCTAssertEqual(updateParams?.repeating, self.dummyRepeating)
        XCTAssertEqual(updateParams?.repeatingUpdateScope, nil)
        XCTAssertEqual(updateParams?.notificationOptions, [.atTime])
        
        let savedDetail = self.spyEventDetailDataUsecase.savedDetail
        XCTAssertEqual(savedDetail?.memo, "new_memo")
        XCTAssertEqual(savedDetail?.url, "new_url")
    }
    
    // 반복이벤트 - 수정하려는 instance가 반복 시작시간인 경우 - 모두수정, 이번만 수정 옵션 제공
    func testViewModel_whenEditRepeatingEventAndTargetEventTurnIsRepeatingStart_provideEditOption_allAndOnlyThisTime() {
        // given
        let viewModel = self.makeViewModelWithPrepare(
            isNotRepeating: false,
            repeatingEventTargetTime: .at(0)
        )
        
        // when
        self.enter(viewModel) {
            $0 |> \.name .~ "new name"
        }
        viewModel.save()
        
        // then
        let actions = self.spyRouter.didShowActionSheetWith?.actions
        XCTAssertEqual(actions?.map { $0.text }, [
            "eventDetail.edit::repeating::confirm::all::button".localized(),
            "eventDetail.edit::repeating::confirm::onlyThisTime::button".localized(),
            "common.cancel".localized()
        ])
    }
    
    // 반복이벤트 - 수정하려는 instance가 반복 시작시간이 아닌경우 - 이번부터 수정, 이번만 수정 옵션 제공
    func testViewModel_whenEditRepeatingEventAndTargetEventTurnIsNotRepeatingStart_provideEditOption_fromNowAndOnlyThisTime() {
        // given
        let viewModel = self.makeViewModelWithPrepare(
            isNotRepeating: false,
            repeatingEventTargetTime: .at(100)
        )
        
        // when
        self.enter(viewModel) {
            $0 |> \.name .~ "new name"
        }
        viewModel.save()
        
        // then
        let actions = self.spyRouter.didShowActionSheetWith?.actions
        XCTAssertEqual(actions?.map { $0.text }, [
            "eventDetail.edit::repeating::confirm::fromNow::button".localized(),
            "eventDetail.edit::repeating::confirm::onlyThisTime::button".localized(),
            "common.cancel".localized()
        ])
    }

    // 반복 이벤트의 경우 - 이번 이벤트만 업데이트 - params scope
    func testViewModel_whenEditRepeatingSchedule_askScope_andUpdateOnlyThistime() {
        // given
        let expect = expectation(description: "반복 이벤트의 경우 - 이번 이벤트만 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare(
            isNotRepeating: false,
            repeatingEventTargetTime: .at(100)
        )
        self.spyRouter.actionSheetSelectionMocking = {
            $0.actions.first(where: { $0.text == "eventDetail.edit::repeating::confirm::onlyThisTime::button".localized() })
        }
        
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            self.enter(viewModel) {
                $0
                |> \.name .~ "new_name"
                |> \.selectedTime .~ pure(SelectedTime(.at(200), self.timeZone))
                |> \.eventRepeating .~ .init(self.dummyRepeating, timeZone: self.timeZone)
                |> \.eventTagId .~ .default
                |> \.eventNotifications .~ [.atTime]
                
            } detaiil: {
                $0 |> \.memo .~ "new_memo"
                    |> \.url .~ "new_url"
            }
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.scheduleEvent_saved::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let updateParams = self.spyScheduleUsecase.didUpdateEditParams
        XCTAssertEqual(updateParams?.name, "new_name")
        XCTAssertEqual(updateParams?.eventTagId, .default)
        XCTAssertEqual(updateParams?.time, .at(200))
        XCTAssertEqual(updateParams?.repeating, nil)
        XCTAssertEqual(updateParams?.repeatingUpdateScope, .onlyThisTime(.at(100)))
        XCTAssertEqual(updateParams?.notificationOptions, [.atTime])
        
        let savedDetail = self.spyEventDetailDataUsecase.savedDetail
        XCTAssertEqual(savedDetail?.eventId, "exclude_event")
        XCTAssertEqual(savedDetail?.memo, "new_memo")
        XCTAssertEqual(savedDetail?.url, "new_url")
    }
    
    // 반복 이벤트의 경우 - 이번 이벤트만 업데이트 - params scope - 시간은 안바꿈
    func testViewModel_whenEditRepeatingSchedule_askScope_andUpdateOnlyThistime_withoutChangeTime() {
        // given
        let expect = expectation(description: "반복 이벤트의 경우 - 이번 이벤트만 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare(
            isNotRepeating: false,
            repeatingEventTargetTime: .at(100)
        )
        self.spyRouter.actionSheetSelectionMocking = {
            $0.actions.first(where: { $0.text == "eventDetail.edit::repeating::confirm::onlyThisTime::button".localized() })
        }
        
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            self.enter(viewModel) {
                $0
                |> \.name .~ "new_name"
                // 실제로 초기값 현재 시간으로 선택됨
                |> \.selectedTime .~ pure(SelectedTime(.at(100), self.timeZone))
                |> \.eventRepeating .~ .init(self.dummyRepeating, timeZone: self.timeZone)
                |> \.eventTagId .~ .default
                |> \.eventNotifications .~ [.atTime]
                
            } detaiil: {
                $0 |> \.memo .~ "new_memo"
                    |> \.url .~ "new_url"
            }
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.scheduleEvent_saved::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let updateParams = self.spyScheduleUsecase.didUpdateEditParams
        XCTAssertEqual(updateParams?.name, "new_name")
        XCTAssertEqual(updateParams?.eventTagId, .default)
        XCTAssertEqual(updateParams?.time, .at(100))
        XCTAssertEqual(updateParams?.repeating, nil)
        XCTAssertEqual(updateParams?.repeatingUpdateScope, .onlyThisTime(.at(100)))
        XCTAssertEqual(updateParams?.notificationOptions, [.atTime])
        
        let savedDetail = self.spyEventDetailDataUsecase.savedDetail
        XCTAssertEqual(savedDetail?.eventId, "exclude_event")
        XCTAssertEqual(savedDetail?.memo, "new_memo")
        XCTAssertEqual(savedDetail?.url, "new_url")
    }
    
    // 반복 이벤트의 경우 - 이번부터 이벤트 변경
    func testViewModel_whenEditRepeatingSchedule_askScope_andUpdateFromNow() {
        // given
        let expect = expectation(description: "반복 이벤트의 경우 - 이번부터 이벤트 변경")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare(isNotRepeating: false, repeatingEventTargetTime: .at(100))
        self.spyRouter.actionSheetSelectionMocking = {
            $0.actions.first(where: { $0.text == "eventDetail.edit::repeating::confirm::fromNow::button".localized() })
        }
        
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            self.enter(viewModel) {
                $0
                |> \.name .~ "new_name"
                |> \.selectedTime .~ pure(SelectedTime(.at(200), self.timeZone))
                |> \.eventRepeating .~ .init(self.dummyRepeating, timeZone: self.timeZone)
                |> \.eventTagId .~ .default
                |> \.eventNotifications .~ [.atTime]
                
            } detaiil: {
                $0 |> \.memo .~ "new_memo"
                    |> \.url .~ "new_url"
            }
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.scheduleEvent_saved::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let updateParams = self.spyScheduleUsecase.didUpdateEditParams
        XCTAssertEqual(updateParams?.name, "new_name")
        XCTAssertEqual(updateParams?.eventTagId, .default)
        XCTAssertEqual(updateParams?.time, .at(200))
        XCTAssertEqual(updateParams?.repeating, self.dummyRepeating)
        XCTAssertEqual(updateParams?.repeatingUpdateScope, .fromNow(.at(100)))
        XCTAssertEqual(updateParams?.notificationOptions, [.atTime])
        
        let savedDetail = self.spyEventDetailDataUsecase.savedDetail
        XCTAssertEqual(savedDetail?.eventId, "branched_event")
        XCTAssertEqual(savedDetail?.memo, "new_memo")
        XCTAssertEqual(savedDetail?.url, "new_url")
    }
    
    // 반복 이벤트의 경우 - 이번부터 이벤트 변경 - 시간변경은 안함
    func testViewModel_whenEditRepeatingSchedule_askScope_andUpdateFromNow_withoutSelectTime() {
        // given
        let expect = expectation(description: "반복 이벤트의 경우 - 이번부터 이벤트 변경")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare(isNotRepeating: false, repeatingEventTargetTime: .at(100))
        self.spyRouter.actionSheetSelectionMocking = {
            $0.actions.first(where: { $0.text == "eventDetail.edit::repeating::confirm::fromNow::button".localized() })
        }
        
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            self.enter(viewModel) {
                $0
                |> \.name .~ "new_name"
                |> \.selectedTime .~ pure(SelectedTime(.at(100), self.timeZone))
                |> \.eventRepeating .~ .init(self.dummyRepeating, timeZone: self.timeZone)
                |> \.eventTagId .~ .default
                |> \.eventNotifications .~ [.atTime]
                
            } detaiil: {
                $0 |> \.memo .~ "new_memo"
                    |> \.url .~ "new_url"
            }
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.scheduleEvent_saved::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let updateParams = self.spyScheduleUsecase.didUpdateEditParams
        XCTAssertEqual(updateParams?.name, "new_name")
        XCTAssertEqual(updateParams?.eventTagId, .default)
        XCTAssertEqual(updateParams?.time, .at(100))
        XCTAssertEqual(updateParams?.repeating, self.dummyRepeating)
        XCTAssertEqual(updateParams?.repeatingUpdateScope, .fromNow(.at(100)))
        XCTAssertEqual(updateParams?.notificationOptions, [.atTime])
        
        let savedDetail = self.spyEventDetailDataUsecase.savedDetail
        XCTAssertEqual(savedDetail?.eventId, "branched_event")
        XCTAssertEqual(savedDetail?.memo, "new_memo")
        XCTAssertEqual(savedDetail?.url, "new_url")
    }
    
    // 반복 이벤트의 경우 - 모든 이벤트 변경
    func testViewModel_whenEditRepeatingSchedule_askScope_andUpdateAll() {
        // given
        let expect = expectation(description: "반복 이벤트의 경우 - 모든 이벤트 변경")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare(
            isNotRepeating: false,
            repeatingEventTargetTime: .at(0)
        )
        self.spyRouter.actionSheetSelectionMocking = {
            $0.actions.first(where: { $0.text == "eventDetail.edit::repeating::confirm::all::button".localized() })
        }
        
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            self.enter(viewModel) {
                $0
                |> \.name .~ "new_name"
                |> \.selectedTime .~ pure(SelectedTime(.at(200), self.timeZone))
                |> \.eventRepeating .~ .init(self.dummyRepeating, timeZone: self.timeZone)
                |> \.eventTagId .~ .default
                |> \.eventNotifications .~ [.atTime]
                
            } detaiil: {
                $0 |> \.memo .~ "new_memo"
                    |> \.url .~ "new_url"
            }
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.scheduleEvent_saved::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let updateParams = self.spyScheduleUsecase.didUpdateEditParams
        XCTAssertEqual(updateParams?.name, "new_name")
        XCTAssertEqual(updateParams?.eventTagId, .default)
        XCTAssertEqual(updateParams?.time, .at(200))
        XCTAssertEqual(updateParams?.repeating, self.dummyRepeating)
        XCTAssertEqual(updateParams?.repeatingUpdateScope, .all)
        XCTAssertEqual(updateParams?.notificationOptions, [.atTime])
        
        let savedDetail = self.spyEventDetailDataUsecase.savedDetail
        XCTAssertEqual(savedDetail?.eventId, "dummy_schedule")
        XCTAssertEqual(savedDetail?.memo, "new_memo")
        XCTAssertEqual(savedDetail?.url, "new_url")
    }
    
    // 반복 이벤트의 경우 - 모든 이벤트 변경 - 시간 변경은 없이
    func testViewModel_whenEditRepeatingSchedule_askScope_andUpdateAll_withoutSelectTime() {
        // given
        let expect = expectation(description: "반복 이벤트의 경우 - 모든 이벤트 변경")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare(
            isNotRepeating: false,
            repeatingEventTargetTime: .at(0)
        )
        self.spyRouter.actionSheetSelectionMocking = {
            $0.actions.first(where: { $0.text == "eventDetail.edit::repeating::confirm::all::button".localized() })
        }
        
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            self.enter(viewModel) {
                $0
                |> \.name .~ "new_name"
                |> \.eventRepeating .~ .init(self.dummyRepeating, timeZone: self.timeZone)
                |> \.eventTagId .~ .default
                |> \.eventNotifications .~ [.atTime]
                
            } detaiil: {
                $0 |> \.memo .~ "new_memo"
                    |> \.url .~ "new_url"
            }
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.scheduleEvent_saved::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let updateParams = self.spyScheduleUsecase.didUpdateEditParams
        XCTAssertEqual(updateParams?.name, "new_name")
        XCTAssertEqual(updateParams?.eventTagId, .default)
        XCTAssertEqual(updateParams?.time, .at(0))
        XCTAssertEqual(updateParams?.repeating, self.dummyRepeating)
        XCTAssertEqual(updateParams?.repeatingUpdateScope, .all)
        XCTAssertEqual(updateParams?.notificationOptions, [.atTime])
        
        let savedDetail = self.spyEventDetailDataUsecase.savedDetail
        XCTAssertEqual(savedDetail?.memo, "new_memo")
        XCTAssertEqual(savedDetail?.url, "new_url")
    }
    
    // 이벤트 저장 실패시 에러 알림
    func testViewModel_whenEditTodoFail_showError() {
        // given
        let expect = expectation(description: "schedule 수정 실패시에 에러 알림")
        let viewModel = self.makeViewModelWithPrepare(
            isNotRepeating: true,
            shouldFailEdit: true
        )
        self.spyRouter.actionSheetSelectionMocking = { $0.actions.first }
        self.spyRouter.didShowErrorCallback = { _ in expect.fulfill() }
        
        // when
        self.enter(viewModel) { $0 |> \.name .~ "new_name" }
        viewModel.save()
        
        // then
        self.wait(for: [expect], timeout: 0.1)
    }
}

private final class PrivateStubScheduleEventUsecase: StubScheduleEventUsecase, @unchecked Sendable {
    
    override func updateScheduleEvent(_ eventId: String, _ params: SchedulePutParams) async throws -> ScheduleEvent {
        let result = try await super.updateScheduleEvent(eventId, params)
        
        let replaceId: (String) -> ScheduleEvent = {
            return ScheduleEvent(uuid: $0, name: params.name ?? result.name, time: params.time ?? result.time)
        }
        
        switch params.repeatingUpdateScope {
        case .all, .none:
            return replaceId(eventId)
        case .fromNow:
            return replaceId("branched_event")
        case .onlyThisTime:
            return replaceId("exclude_event")
        }
    }
}
