//
//  EditTodoEventDetailViewModelImpleTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 11/7/23.
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


class EditTodoEventDetailViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyTodoUsecase: StubTodoEventUsecase!
    private var spyEventDetailDataUsecase: StubEventDetailDataUsecase!
    private var stubForemostEventUsecase: StubForemostEventUsecase!
    private var spyRouter: SpyEventDetailRouter!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyTodoUsecase = .init()
        self.spyEventDetailDataUsecase = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyTodoUsecase = nil
        self.spyEventDetailDataUsecase = nil
        self.stubForemostEventUsecase = nil
        self.spyRouter = nil
    }
    
    private var timeZone: TimeZone {
        return TimeZone(abbreviation: "KST")!
    }
    
    private func makeViewModel(
        customTodo: TodoEvent? = nil,
        shouldFailSave: Bool = false,
        isForemost: Bool = false
    ) -> EditTodoEventDetailViewModelImple {
        
        let (todo, detail) = (customTodo ?? self.dummyRepeatingTodo, self.dummyDetail)
        self.spyTodoUsecase.stubTodo = todo
        self.spyEventDetailDataUsecase.stubDetail = detail
        self.spyTodoUsecase.shouldUpdateEventFail = shouldFailSave
        
        let tagUsecase = StubEventTagUsecase()
        
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.selectTimeZone(self.timeZone)
        
        self.stubForemostEventUsecase = .init(
            foremostId: isForemost ? .init(event: todo) : nil
        )
        self.stubForemostEventUsecase.refresh()
        
        let viewModel = EditTodoEventDetailViewModelImple(
            todoId: todo.uuid,
            todoUsecase: self.spyTodoUsecase,
            eventTagUsecase: tagUsecase,
            eventDetailDataUsecase: self.spyEventDetailDataUsecase,
            calendarSettingUsecase: calendarSettingUsecase,
            foremostEventUsecase: self.stubForemostEventUsecase
        )
        viewModel.router = self.spyRouter
        viewModel.attachInput()
        return viewModel
    }
    
    private var dummyRepeating: EventRepeating {
        return EventRepeating(
            repeatingStartTime: 0, repeatOption: EventRepeatingOptions.EveryDay()
        ) |> \.repeatingEndTime .~ 100
    }
    
    private var dummyRepeatingTodo: TodoEvent {
        return TodoEvent(uuid: "dummy_todo", name: "dummy")
        |> \.time .~ .at(0)
        |> \.repeating .~ pure(self.dummyRepeating)
        |> \.eventTagId .~ .custom("tag")
        |> \.notificationOptions .~ [.atTime, .before(seconds: 100)]
    }
    
    private var dummyDetail: EventDetailData {
        return EventDetailData("dummy_todo")
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

extension EditTodoEventDetailViewModelImpleTests {
    
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
        XCTAssertEqual(preparedWith?.0.name, self.dummyRepeatingTodo.name)
        XCTAssertEqual(preparedWith?.0.selectedTime, .init(self.dummyRepeatingTodo.time!, self.timeZone))
        XCTAssertEqual(preparedWith?.0.eventRepeating, .init(self.dummyRepeating, timeZone: self.timeZone))
        XCTAssertEqual(preparedWith?.0.eventTagId, .custom("tag"))
        XCTAssertEqual(preparedWith?.0.eventNotifications, [.atTime, .before(seconds: 100)])
        XCTAssertEqual(preparedWith?.1, self.dummyDetail)
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
                    foremost: .init("dummy_todo", true)
                )
                
                try await self.stubForemostEventUsecase.update(
                    foremost: .init("another_todo", true)
                )
            }
        }
        
        // then
        XCTAssertEqual(isForemosts, [false, true, false])
    }
    
    // isTodo == true + isTodoOrScheduleTogglable == false
    func testViewModel_isTodoAndIsTodoOrScheduleNotTogglable() {
        // given
        let expect = expectation(description: " isTodo == true + isTodoOrScheduleTogglable == false")
        let viewModel = self.makeViewModel()
        
        // when
        let typeModel = self.waitFirstOutput(expect, for: viewModel.eventDetailTypeModel)
        
        // then
        XCTAssertEqual(typeModel, EventDetailTypeModel.todoCase())
    }
    
    func testViewModel_provideEventDetailMoreActions() {
        // given
        func parameterizeTest(
            _ viewModel: EditTodoEventDetailViewModelImple,
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
        let todo = self.dummyRepeatingTodo
        parameterizeTest(
            self.makeViewModel(customTodo: todo),
            expect: [
                [.remove(onlyThisEvent: true), .remove(onlyThisEvent: false)], 
                [.toggleTo(isForemost: true)]
            ]
        )
        parameterizeTest(
            self.makeViewModel(customTodo: todo, isForemost: true),
            expect: [
                [.remove(onlyThisEvent: true), .remove(onlyThisEvent: false)],
                [.toggleTo(isForemost: false)]
            ]
        )
        let todoNotRepeating = todo |> \.repeating .~ nil
        parameterizeTest(
            self.makeViewModel(customTodo: todoNotRepeating),
            expect: [
                [.remove(onlyThisEvent: false)],
                [.toggleTo(isForemost: true)]
            ]
        )
    }
    
    func testViewModel_whenAfterRemoveTodo_closeScene() {
        // given
        let expect = expectation(description: "todo 삭제 이후에 화면 닫음")
        self.spyRouter.didCloseCallback = { expect.fulfill() }
        let viewModel = self.makeViewModelWithPrepare()
        
        // when
        viewModel.handleMoreAction(.remove(onlyThisEvent: true))
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.todoEvent_removed::message".localized())
    }
    
    func testViewModel_toggleForemost() {
        // given
        let expect = expectation(description: "foremost 토글")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let isForemosts = self.waitOutputs(expect, for: viewModel.isForemost) {
            viewModel.handleMoreAction(.toggleTo(isForemost: true))
        }
        
        // then
        XCTAssertEqual(isForemosts, [false, true])
    }
}


// MARK: - test save changes

extension EditTodoEventDetailViewModelImpleTests {
    
    private func makeViewModelWithPrepare(
        isNotRepeating: Bool = false,
        shouldFailEdit: Bool = false
    ) -> EditTodoEventDetailViewModelImple {
        // given
        let expect = expectation(description: "wait prepared")
        expect.expectedFulfillmentCount = 3
        
        let todo = if isNotRepeating {
            self.dummyRepeatingTodo |> \.repeating .~ nil
        } else {
            self.dummyRepeatingTodo
        }
        let viewModel = self.makeViewModel(customTodo: todo, shouldFailSave: shouldFailEdit)
        
        // when
        let _ = self.waitOutputs(expect, for: viewModel.isLoading) {
            viewModel.prepare()
        }
        
        // then
        return viewModel
    }
    
    private func enter(
        _ viewModel: EditTodoEventDetailViewModelImple,
        _ todo: TodoEvent? = nil,
        basic: (EventDetailBasicData) -> EventDetailBasicData,
        detaiil: (EventDetailData) -> EventDetailData = { $0 }
    ) {
        let todo = todo ?? self.dummyRepeatingTodo
        let oldBasic = EventDetailBasicData(
            name: todo.name,
            eventTagId: todo.eventTagId ?? .default
        )
        |> \.selectedTime .~ todo.time.map { .init($0, self.timeZone) }
        |> \.eventRepeating .~ todo.repeating.flatMap { .init($0, timeZone: self.timeZone) }
        let newBasic = basic(oldBasic)
        let newDetail = detaiil(self.dummyDetail)
        viewModel.eventDetail(didInput: newBasic, additional: newDetail)
    }
    
    // name만 있으면 저장 가능해짐
    func testViewModel_whenEnterName_isSavabla() {
        // given
        let expect = expectation(description: "name이 있고 선택시간이 유효하면 저장 가능해짐")
        expect.expectedFulfillmentCount = 6
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
        }
        
        // then
        XCTAssertEqual(isSavables, [true, false, true, false, true, false])
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
        XCTAssertEqual(self.spyTodoUsecase.didUpdateEditParams, nil)
        XCTAssertEqual(self.spyEventDetailDataUsecase.savedDetail, nil)
    }
    
    // 비 반복 이벤트의 경우 변경사항 저장 - todo 저장하고, detail도 저장
    func testViewModel_whenNotRpeatingTodo_saveTodoAndDetail() {
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
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.todoEvent_saved::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let updateParams = self.spyTodoUsecase.didUpdateEditParams
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

    // 반복 이벤트의 경우 - 이번 이벤트만 업데이트 - params scope
    func testViewModel_whenEditRepeatingTodo_askScope_andUpdateOnlyThistime() {
        // given
        let expect = expectation(description: "반복 이벤트의 경우 - 이번 이벤트만 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare(isNotRepeating: false)
        self.spyRouter.shouldConfirmNotCancel = true
        
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
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.todoEvent_saved::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let updateParams = self.spyTodoUsecase.didUpdateEditParams
        XCTAssertEqual(updateParams?.name, "new_name")
        XCTAssertEqual(updateParams?.eventTagId, .default)
        XCTAssertEqual(updateParams?.time, .at(100))
        XCTAssertEqual(updateParams?.repeating, self.dummyRepeating)
        XCTAssertEqual(updateParams?.repeatingUpdateScope, .onlyThisTime)
        XCTAssertEqual(updateParams?.notificationOptions, [.atTime])
        
        let savedDetail = self.spyEventDetailDataUsecase.savedDetail
        XCTAssertEqual(savedDetail?.memo, "new_memo")
        XCTAssertEqual(savedDetail?.url, "new_url")
    }
    
    // 반복 이벤트의 경우 - 모든 이벤트 변경
    func testViewModel_whenEditRepeatingTodo_askScope_andUpdateAll() {
        // given
        let expect = expectation(description: "반복 이벤트의 경우 - 모든 이벤트 변경")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare(isNotRepeating: false)
        self.spyRouter.shouldConfirmNotCancel = false
        
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
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.todoEvent_saved::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let updateParams = self.spyTodoUsecase.didUpdateEditParams
        XCTAssertEqual(updateParams?.name, "new_name")
        XCTAssertEqual(updateParams?.eventTagId, .default)
        XCTAssertEqual(updateParams?.time, .at(100))
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
        let expect = expectation(description: "todo 수정 실패시에 에러 알림")
        let viewModel = self.makeViewModelWithPrepare(shouldFailEdit: true)
        self.spyRouter.didShowErrorCallback = { _ in expect.fulfill() }
        
        // when
        self.enter(viewModel) { $0 |> \.name .~ "new_name" }
        viewModel.save()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
}
