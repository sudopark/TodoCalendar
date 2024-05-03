//
//  EventDetailInputViewModelTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 11/5/23.
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


class EventDetailInputViewModelTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var spyListener: SpyListener!
    private var refDate: Date!
    private var timeZone: TimeZone {
        return TimeZone(abbreviation: "KST")!
    }
    
    private var thisYearRefDate: Date {
        let calenar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
        let year = calenar.component(.year, from: Date())
        return calenar.date(bySetting: .year, value: year, of: self.refDate)!
    }
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        self.spyListener = .init()
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
        let compos = DateComponents(year: 2023, month: 9, day: 18, hour: 4, minute: 44)
        self.refDate = calendar.date(from: compos)
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.spyListener = nil
        self.refDate = nil
    }
    
    private func makeViewModel() -> EventDetailInputViewModelImple {
        
        let tagUsecase = StubEventTagUsecase()
        tagUsecase.prepare()
        
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        
        let viewModel = EventDetailInputViewModelImple(
            eventTagUsecase: tagUsecase,
            calendarSettingUsecase: settingUsecase
        )
        viewModel.routing = self.spyRouter
        viewModel.listener = self.spyListener
        viewModel.setup()
        
        return viewModel
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
    
    private var dummyRepeating: EventRepeating {
        return .init(
            repeatingStartTime: 0,
            repeatOption: EventRepeatingOptions.EveryDay()
        )
        |> \.repeatingEndTime .~ 100
    }
    
    private var dummyPreviousBasic: EventDetailBasicData {
        let selectedTime = SelectedTime(self.dummy3DaysPeriod, self.timeZone)
        let repeating = EventRepeatingTimeSelectResult(text: "old_repeat", repeating: self.dummyRepeating)
        return EventDetailBasicData(name: "old_name", eventTagId: .custom("some"))
            |> \.selectedTime .~ selectedTime
            |> \.eventRepeating .~ pure(repeating)
    }
    
    private var dummyPreviousAddition: EventDetailData {
        return .init("pending")
            |> \.url .~ "old_url"
            |> \.memo .~ "old_memo"
    }
}


extension EventDetailInputViewModelTests {
    
    private func prepareViewModelWithOldData(_ viewModel: EventDetailInputViewModelImple) {
        viewModel.prepared(
            basic: self.dummyPreviousBasic,
            additional: self.dummyPreviousAddition
        )
    }
    
    // 입력한 값에 따라 초기 이름값 제공
    func testViewModel_whenAfterPrepare_provideInitailName() {
        // given
        let expect = expectation(description: "prepare 이후에 이전에 입혁한 이름값 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let names = self.waitOutputs(expect, for: viewModel.initialName) {
            self.prepareViewModelWithOldData(viewModel)
            
            viewModel.enter(name: "new name")
        }
    
        // then
        XCTAssertEqual(names, ["old_name"])
    }
}


// MARK: - test select

extension EventDetailInputViewModelTests {

    // 태그 선택
    func testViewModel_selectEventTag() {
        // given
        let expect = expectation(description: "이벤트 태그 선택")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let tags = self.waitOutputs(expect, for: viewModel.selectedTag) {
            self.prepareViewModelWithOldData(viewModel)
            viewModel.selectEventTag()
            viewModel.selectEventTag(didSelected: .init(.holiday, "some", .holiday))
        }
        
        // then
        let selectedTagIds = tags.map { $0.tagId }
        XCTAssertEqual(selectedTagIds, [.custom("some"), .holiday])
    }
    
    // 반복옵션 선택
    func testViewModel_whenRepeatTimeSelected_update() {
        // given
        let expect = expectation(description: "이벤트 반복 옵션 선택 이후에 반복시간 업데이트")
        expect.expectedFulfillmentCount = 5
        let viewModel = self.makeViewModel()
        let dummy = EventRepeatingTimeSelectResult(
            text: "Everyday".localized(),
            repeating: EventRepeating(
                repeatingStartTime: self.dummySingleDayPeriod.lowerBoundWithFixed,
                repeatOption: EventRepeatingOptions.EveryDay()
            )
        )
        
        // when
        let repeats = self.waitOutputs(expect, for: viewModel.repeatOption) {
            self.prepareViewModelWithOldData(viewModel)
            viewModel.selectStartTime(self.refDate)
            
            viewModel.selectRepeatOption()
            viewModel.selectEventRepeatOption(didSelect: dummy) // on
            
            viewModel.selectRepeatOption()
            viewModel.selectEventRepeatOptionNotRepeat() // off
            
            viewModel.selectRepeatOption()
            viewModel.selectEventRepeatOption(didSelect: dummy) // on
            
            viewModel.removeTime()
        }
        
        // then
        XCTAssertEqual(repeats, [
            "old_repeat",
            "Everyday".localized(),
            nil,
            "Everyday".localized(),
            nil,
        ])
    }
}


extension EventDetailInputViewModelTests {
    
    func testViewModel_whenInputData_notify() {
        // given
        let viewModel = self.makeViewModel()
        self.prepareViewModelWithOldData(viewModel)
        
        // enter name
        viewModel.enter(name: "new_name")
        XCTAssertEqual(self.spyListener.didUpdateBasics.last?.name, "new_name")
        
        // select option
        XCTAssertEqual(
            self.spyListener.didUpdateBasics.last?.eventRepeating?.text,
            "old_repeat"
        )
        viewModel.selectRepeatOption()
        viewModel.selectEventRepeatOption(didSelect:
                .init(text: "new_repeat", repeating: self.dummyRepeating)
        )
        XCTAssertEqual(
            self.spyListener.didUpdateBasics.last?.eventRepeating?.text,
            "new_repeat"
        )
        viewModel.selectEventRepeatOptionNotRepeat()
        XCTAssertEqual(self.spyListener.didUpdateBasics.last?.eventRepeating?.text, nil)
        
        // select time
        XCTAssertEqual(
            self.spyListener.didUpdateBasics.last?.selectedTime,
            SelectedTime(self.dummy3DaysPeriod, self.timeZone)
        )
        viewModel.selectStartTime(self.refDate.add(days: 1)!)
        XCTAssertEqual(
            self.spyListener.didUpdateBasics.last?.selectedTime, 
            SelectedTime(.period(self.refDate.add(days: 1)!.timeIntervalSince1970..<self.refDate.add(days: 3)!.timeIntervalSince1970), self.timeZone)
        )
        
        // select event time
        XCTAssertEqual(
            self.spyListener.didUpdateBasics.last?.eventNotifications,
            []
        )
        viewModel.selectEventNotificationTime(didUpdate: [.atTime])
        XCTAssertEqual(
            self.spyListener.didUpdateBasics.last?.eventNotifications,
            [.atTime]
        )
        
        // toggle all day
        viewModel.toggleIsAllDay()
        XCTAssertEqual(
            self.spyListener.didUpdateBasics.last?.eventNotifications,
            []
        )
        
        viewModel.selectEventNotificationTime(didUpdate: [.allDay9AM])
        XCTAssertEqual(
            self.spyListener.didUpdateBasics.last?.eventNotifications,
            [.allDay9AM]
        )
        
        // remove time
        viewModel.removeTime()
        XCTAssertEqual(
            self.spyListener.didUpdateBasics.last?.selectedTime,
            nil
        )
        XCTAssertEqual(
            self.spyListener.didUpdateBasics.last?.eventNotifications,
            []
        )
        
        // select tag
        XCTAssertEqual(
            self.spyListener.didUpdateBasics.last?.eventTagId,
            .custom("some")
        )
        viewModel.selectEventTag()
        viewModel.selectEventTag(didSelected: .defaultTag)
        XCTAssertEqual(self.spyListener.didUpdateBasics.last?.eventTagId, .default)
        
        // enter url and memo
        XCTAssertEqual(self.spyListener.didUpdateAdditions.last?.url, "old_url")
        viewModel.enter(url: "new_url")
        
        XCTAssertEqual(self.spyListener.didUpdateAdditions.last?.memo, "old_memo")
        viewModel.enter(memo: "new_memo")
        XCTAssertEqual(self.spyListener.didUpdateAdditions.last?.memo, "new_memo")
    }
}


// MARK: - notification time

extension EventDetailInputViewModelTests {
    
    func testViewModel_provideEventNotificationTimeText_whenPrepare() {
        // given
        func parameterizeTest(
            with basic: EventDetailBasicData,
            expectText: String?
        ) {
            // given
            let expect = expectation(description: "초기 이벤트 알림시간 정보 제공")
            let viewModel = self.makeViewModel()
            
            // when
            let text = self.waitFirstOutput(expect, for: viewModel.selectedNotificationTimeText) {
                viewModel.prepared(basic: basic, additional: self.dummyPreviousAddition)
            }
            
            // then
            XCTAssertEqual(text, expectText)
        }
        // when + then
        parameterizeTest(
            with: self.dummyPreviousBasic |> \.eventNotifications .~ [],
            expectText: nil
        )
        parameterizeTest(
            with: self.dummyPreviousBasic |> \.eventNotifications .~ [.atTime],
            expectText: "event_notification_setting::option_title::at_time".localized()
        )
        parameterizeTest(
            with: self.dummyPreviousBasic |> \.eventNotifications .~ [.atTime, .before(seconds: 60)],
            expectText: "\("event_notification_setting::option_title::at_time".localized()) and \("event_notification_setting::option_title::before_minutes".localized(with: 1))"
        )
        parameterizeTest(
            with: self.dummyPreviousBasic |> \.eventNotifications .~ [.atTime, .before(seconds: 60), .before(seconds: 120)],
            expectText: "\("event_notification_setting::option_title::at_time".localized()), \("event_notification_setting::option_title::before_minutes".localized(with: 1)) and \("event_notification_setting::option_title::before_minutes".localized(with: 2))"
        )
    }
    
    // 이벤트 알림시간 설정 및 업데이트 - 초기값 전달
    func testViewModel_routeToSelectEventNotificationTime_withInitialData() {
        // given
        func parameterizeTest(
            with basic: EventDetailBasicData,
            expectIsForAllDay: Bool,
            options: [EventNotificationTimeOption]
        ) {
            // given
            let expect = expectation(description: "wait notificaiton time text")
            let viewModel = self.makeViewModel()
            
            // when
            let _ = self.waitFirstOutput(expect, for: viewModel.selectedNotificationTimeText) {
                viewModel.prepared(basic: basic, additional: self.dummyPreviousAddition)
            }
            viewModel.selectNotificationTime()
            
            // then
            let params = self.spyRouter.didRouteToEventNotificationWithParams
            XCTAssertEqual(params?.0, expectIsForAllDay)
            XCTAssertEqual(params?.1, options)
        }
        
        // when + then
        parameterizeTest(
            with: self.dummyPreviousBasic
                |> \.eventNotifications .~ [.atTime],
            expectIsForAllDay: false,
            options: [.atTime]
        )
        parameterizeTest(
            with: self.dummyPreviousBasic
                |> \.selectedTime .~ SelectedTime(.allDay(0..<10, secondsFromGMT: 0), self.timeZone)
                |> \.eventNotifications .~ [.allDay9AM],
            expectIsForAllDay: true,
            options: [.allDay9AM]
        )
    }
}

private class SpyRouter: BaseSpyRouter, EventDetailInputRouting, @unchecked Sendable {
    
    var didRouteToEventRepeatOptionSelect: Bool?
    func routeToEventRepeatOptionSelect(
        startTime: Date, with initalOption: EventRepeating?,
        listener: (any SelectEventRepeatOptionSceneListener)?
    ) {
        self.didRouteToEventRepeatOptionSelect = true
    }
    
    var didRouteToSelectEventTag: Bool?
    func routeToEventTagSelect(
        currentSelectedTagId: AllEventTagId,
        listener: (any SelectEventTagSceneListener)?
    ) {
        self.didRouteToSelectEventTag = true
    }
    
    var didRouteToEventNotificationWithParams: (Bool, [EventNotificationTimeOption], DateComponents)?
    func routeToEventNotificationTimeSelect(isForAllDay: Bool, current selecteds: [EventNotificationTimeOption], eventTimeComponents: DateComponents, listener: (SelectEventNotificationTimeSceneListener)?) {
        self.didRouteToEventNotificationWithParams = (isForAllDay, selecteds, eventTimeComponents)
    }
}

private class SpyListener: EventDetailInputListener {
    
    var didUpdateBasics: [EventDetailBasicData] = []
    var didUpdateAdditions: [EventDetailData] = []
    var didEnterEventDetailCallback: (() -> Void)?
    func eventDetail(didInput basic: EventDetailBasicData, additional: EventDetailData) {
        self.didUpdateBasics.append(basic)
        self.didUpdateAdditions.append(additional)
        self.didEnterEventDetailCallback?()
    }
}
