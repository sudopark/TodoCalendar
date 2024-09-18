//
//  AddEventViewModelImpleTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 10/15/23.
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


class AddEventViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyTodoUsecase: StubTodoEventUsecase!
    private var spyScheduleUsecase: StubScheduleEventUsecase!
    private var spyEventDetailDataUsecase: StubEventDetailDataUsecase!
    private var spyRouter: SpyEventDetailRouter!
    private var refDate: Date!
    private var timeZone: TimeZone {
        return TimeZone(abbreviation: "KST")!
    }
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyTodoUsecase = .init()
        self.spyScheduleUsecase = .init()
        self.spyEventDetailDataUsecase = .init()
        self.spyRouter = .init()
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
        let compos = DateComponents(year: 2023, month: 9, day: 18, hour: 4, minute: 44)
        self.refDate = calendar.date(from: compos)
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyTodoUsecase = nil
        self.spyScheduleUsecase = nil
        self.spyEventDetailDataUsecase = nil
        self.spyRouter = nil
        self.refDate = nil
    }
    
    private func makeViewModel(
        latestTagExists: Bool = true,
        defaultPeriod: EventSettings.DefaultNewEventPeriod = .hour1,
        shouldFailSaveDetailData: Bool = false
    ) -> AddEventViewModelImple {
        
        let tagUsecase = StubEventTagUsecase()
        tagUsecase.prepare()
        
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        
        let eventSettingUsecase = StubEventSettingUsecase()
        eventSettingUsecase.stubSetting = .init()
        eventSettingUsecase.stubSetting?.defaultNewEventTagId = latestTagExists
            ? .custom("latest") : .default
        eventSettingUsecase.stubSetting?.defaultNewEventPeriod = defaultPeriod
        
        let eventNotificationSettingUsecase = StubEventNotificationSettingUsecase()
        eventNotificationSettingUsecase.saveDefaultNotificationTimeOption(forAllDay: false, option: .atTime)
        
        let viewModel = AddEventViewModelImple(
            params: .init(selectedDate: self.refDate),
            todoUsecase: self.spyTodoUsecase,
            scheduleUsecase: self.spyScheduleUsecase,
            eventTagUsease: tagUsecase,
            calendarSettingUsecase: settingUsecase,
            eventDetailDataUsecase: self.spyEventDetailDataUsecase,
            eventSettingUsecase: eventSettingUsecase,
            eventNotificationSettingUsecase: eventNotificationSettingUsecase
        )
        viewModel.router = self.spyRouter
        viewModel.attachInput()
        return viewModel
    }
    
    private var defaultCurrentAndNextHourSelectTime: SelectedTime {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let now = calendar.dateBySetting(from: Date()) {
            $0.year = 2023
            $0.month = 9
            $0.day = 18
        }!
        let next = now.addingTimeInterval(3600)
        return .period(
            .init(now.timeIntervalSince1970, self.timeZone),
            .init(next.timeIntervalSince1970, self.timeZone)
        )
    }
    
    private var defaultCurrentAtSelectTime: SelectedTime {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let now = calendar.dateBySetting(from: Date()) {
            $0.year = 2023
            $0.month = 9
            $0.day = 18
        }!
        return .at(.init(now.timeIntervalSince1970, self.timeZone))
    }
    
    private var defaultSingleAllDaySelectTime: SelectedTime {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
        let now = calendar.dateBySetting(from: Date()) {
            $0.year = 2023
            $0.month = 9
            $0.day = 18
        }!
        return .singleAllDay(
            .init(now.timeIntervalSince1970, timeZone, withoutTime: true)
        )
    }
    
    private var dummySingleDayPeriod: EventTime {
        let start = self.refDate!; let next = start.addingTimeInterval(3600)
        return .period(start.timeIntervalSince1970..<next.timeIntervalSince1970)
    }
    
    private var dummy3DaysPeriod: EventTime {
        let start = self.refDate!; let next = start.add(days: 3)!
        return .period(start.timeIntervalSince1970..<next.timeIntervalSince1970)
    }
    
    private var dummySingleAllDayPeriod: EventTime {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
        let start = calendar.startOfDay(for: self.refDate!)
        let end = calendar.endOfDay(for: start)!
        return .allDay(
            start.timeIntervalSince1970..<end.timeIntervalSince1970,
            secondsFromGMT: self.timeZone.secondsFromGMT() |> TimeInterval.init
        )
    }
    
    private var dummyAll3DaysPeriod: EventTime {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let start = calendar.startOfDay(for: self.refDate!)
        let nextDate = self.refDate!.add(days: 3)!
        let end = calendar.endOfDay(for: nextDate)!
        return .allDay(
            start.timeIntervalSince1970..<end.timeIntervalSince1970,
            secondsFromGMT: self.timeZone.secondsFromGMT() |> TimeInterval.init
        )
    }
}

// MARK: - initail value

extension AddEventViewModelImpleTests {
    
    func testViewModel_attachInputSceneWithInitialValues() {
        // given
        let expect = expectation(description: "최초에 초기값과 함께 입력부 attach")
        let viewModel = self.makeViewModel()
        self.spyRouter.spyInteractor.didPreparedCallback = {
            expect.fulfill()
        }
        
        // when
        viewModel.prepare()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(self.spyRouter.didAttachInput, true)
        
        let preparedBasic = self.spyRouter.spyInteractor.didPreparedWith?.0
        XCTAssertEqual(preparedBasic?.name, nil)
        XCTAssertEqual(preparedBasic?.selectedTime, self.defaultCurrentAndNextHourSelectTime)
        XCTAssertEqual(preparedBasic?.eventRepeating, nil)
        XCTAssertEqual(preparedBasic?.eventTagId, .custom("latest"))
        XCTAssertEqual(preparedBasic?.eventNotifications, [.atTime])
        
        let preparedAddition = self.spyRouter.spyInteractor.didPreparedWith?.1
        XCTAssertEqual(preparedAddition?.url, nil)
        XCTAssertEqual(preparedAddition?.memo, nil)
    }
    
    func testViewModel_attachInputSceneWithInitialDefaultPeriod() {
        // given
        func parameterizeTest(
            _ defPeriod: EventSettings.DefaultNewEventPeriod,
            expectTime: SelectedTime
        ) {
            // given
            let expect = expectation(description: "wait")
            let viewModel = self.makeViewModel(defaultPeriod: defPeriod)
            self.spyRouter.spyInteractor.didPreparedCallback = {
                expect.fulfill()
            }
            
            // when
            viewModel.prepare()
            self.wait(for: [expect], timeout: self.timeout)
            
            // then
            let prepredBasic = self.spyRouter.spyInteractor.didPreparedWith?.0
            XCTAssertEqual(prepredBasic?.selectedTime, expectTime)
        }
        // when + then
        parameterizeTest(
            .minute0,
            expectTime: defaultCurrentAtSelectTime
        )
        parameterizeTest(
            .hour1,
            expectTime: defaultCurrentAndNextHourSelectTime
        )
        parameterizeTest(
            .allDay,
            expectTime: defaultSingleAllDaySelectTime
        )
    }
    
    // todo여부 토글
    func testViewModel_updateIsTodo() {
        // given
        let expect = expectation(description: "todo여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let typeModels = self.waitOutputs(expect, for: viewModel.eventDetailTypeModel) {
            viewModel.prepare()
            viewModel.toggleIsTodo()
            viewModel.toggleIsTodo()
        }
        
        // then
        XCTAssertEqual(typeModels, [
            EventDetailTypeModel.makeCase(false),
            EventDetailTypeModel.makeCase(true),
            EventDetailTypeModel.makeCase(false)
        ])
    }
    
    func testViewModel_whenLatestUsedTagNotExists_provideInitialSelectedTagIsDefault() {
        // given
        let expect = expectation(description: "마지막으로 사용했던 태그 존재하지 않으면 기본태그 반환")
        let viewModel = self.makeViewModel(latestTagExists: false)
        self.spyRouter.spyInteractor.didPreparedCallback = { expect.fulfill() }
        
        // when
        viewModel.prepare()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(self.spyRouter.spyInteractor.didPreparedWith?.0.eventTagId, .default)
    }
}


// MARK: - save

extension AddEventViewModelImpleTests {
    
    private func enter(
        _ viewModel: AddEventViewModelImple,
        _ withBasic: (EventDetailBasicData) -> EventDetailBasicData
    ) {
        let initialValue = EventDetailBasicData(name: nil, eventTagId: .custom("latest"))
        let new = withBasic(initialValue)
        viewModel.eventDetail(didInput: new, additional: .init("pending"))
    }
    
    // todo의 경우 이름만 입력하면 저장 가능해짐
    func testViewModel_whenMakeTodo_isSavableWhenEnterName() {
        // given
        let expect = expectation(description: "todo의 경우 이름만 입력하면 저장 가능해짐")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let isSavables = self.waitOutputs(expect, for: viewModel.isSavable) {
            viewModel.prepare()
            viewModel.toggleIsTodo()
            self.enter(viewModel) {
                $0 |> \.name .~ "some"
            }
        }
        
        // then
        XCTAssertEqual(isSavables, [false, true])
    }
    
    // schedule event의 경우 이름 및 시간이 입력되어야함
    func testViewModel_whenMakeScheduleEvent_isSavableWhenEnterNameAndSelectTime() {
        // given
        let expect = expectation(description: "schedule event의 경우 이름 및 시간이 입력되어야함")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isSavables = self.waitOutputs(expect, for: viewModel.isSavable) {
            viewModel.prepare()
            
            self.enter(viewModel) {
                $0
                |> \.name .~ "some"
                |> \.selectedTime .~ self.defaultCurrentAndNextHourSelectTime
            }
            self.enter(viewModel) {
                $0
                |> \.name .~ "some"
                |> \.selectedTime .~ nil
            }
        }
        
        // then
        XCTAssertEqual(isSavables, [false, true, false])
    }
    
    private var dummyNewSelectTime: SelectedTime {
        let time = EventTime.at(0)
        return .init(time, self.timeZone)
    }
    
    private func enterAllInfo(_ viewModel: AddEventViewModelImple) {
        let repeating = EventRepeatingTimeSelectResult(
            text: "some",
            repeating: .init(repeatingStartTime: 100, repeatOption: EventRepeatingOptions.EveryDay()))
        
        let basic = EventDetailBasicData(name: "some", eventTagId: .custom("latest"))
        |> \.selectedTime .~ self.dummyNewSelectTime
        |> \.eventRepeating .~ pure(repeating)
        |> \.eventTagId .~ .custom("some")
        |> \.eventNotifications .~ [.atTime]
        
        let addition = EventDetailData("pending")
        |> \.url .~ "url"
        |> \.memo .~ "memo"
        
        viewModel.eventDetail(didInput: basic, additional: addition)
    }
    
    private func makeViewModelWithPrepare() -> AddEventViewModelImple {
        let expect = expectation(description: "wait")
        let viewModel = self.makeViewModel()
        
        self.spyRouter.spyInteractor.didPreparedCallback = { expect.fulfill() }
        
        viewModel.prepare()
        self.wait(for: [expect], timeout: self.timeout)
        
        return viewModel
    }
    
    // todo 저장 완료 이후에 토스트 노출 + 화면 닫음
    func testViewModel_saveTodo() {
        // given
        let expect = expectation(description: "todo 저장 완료 이후에 토스트 노출 + 화면 닫음")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare()
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            viewModel.toggleIsTodo()
            self.enterAllInfo(viewModel)
            
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.add_new_todo::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let madeParams = self.spyTodoUsecase.didMakeTodoWithParams
        XCTAssertEqual(madeParams?.name, "some")
        XCTAssertEqual(madeParams?.eventTagId, .custom("some"))
        XCTAssertEqual(madeParams?.time, .at(0))
        XCTAssertEqual(madeParams?.repeating, .init(repeatingStartTime: 100, repeatOption: EventRepeatingOptions.EveryDay()) )
        XCTAssertEqual(madeParams?.notificationOptions, [.atTime])
    }
    
    // scheudle 저장
    func testViewModel_saveScheduleEvent() {
        // given
        let expect = expectation(description: "schedule 저장 완료 이후에 토스트 노출 + 화면 닫음")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare()
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            self.enterAllInfo(viewModel)
            
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.add_new_schedule::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let madeParams = self.spyScheduleUsecase.didMakeScheduleParams
        XCTAssertEqual(madeParams?.name, "some")
        XCTAssertEqual(madeParams?.eventTagId, .custom("some"))
        XCTAssertEqual(madeParams?.time, .at(0))
        XCTAssertEqual(madeParams?.repeating, .init(repeatingStartTime: 100, repeatOption: EventRepeatingOptions.EveryDay()) )
        XCTAssertEqual(madeParams?.notificationOptions, [.atTime])
    }
    
    // 이벤트 저장 이후에 메타데이터도 저장함
    func testViewModel_whenAfterSaveTodo_saveDetailData() {
        // given
        let expect = expectation(description: "todo 저장 완료 이후에 event detail data 저장")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare()
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            viewModel.toggleIsTodo()
            self.enterAllInfo(viewModel)
            
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyEventDetailDataUsecase.savedDetail?.memo, "memo")
        XCTAssertEqual(self.spyEventDetailDataUsecase.savedDetail?.url, "url")
    }
    
    func testViewModel_whenAfterSaveSchedule_saveDetailData() {
        // given
        let expect = expectation(description: "schedule 저장 완료 이후에 event detail data 저장")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPrepare()
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            self.enterAllInfo(viewModel)
            
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyEventDetailDataUsecase.savedDetail?.memo, "memo")
        XCTAssertEqual(self.spyEventDetailDataUsecase.savedDetail?.url, "url")
    }
    
    func testViewModel_whenSaveEventDetailDataFail_ignore() {
        // given
        let expect = expectation(description: "todo 저장 완료 이후에 event detail data 저장 실패해도 무시")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(shouldFailSaveDetailData: true)
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            viewModel.prepare()
            viewModel.toggleIsTodo()
            self.enterAllInfo(viewModel)
            
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "eventDetail.add_new_todo::message".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }
}
