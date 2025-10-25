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
    
    private func makeViewModel(
        defaultEventPeriod: EventSettings.DefaultNewEventPeriod = .minute0
    ) -> EventDetailInputViewModelImple {
        
        let tagUsecase = StubEventTagUsecase()
        tagUsecase.prepare()
        
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        
        let eventSettingUsecase = StubEventSettingUsecase()
        eventSettingUsecase.stubSetting = .init()
        eventSettingUsecase.stubSetting?.defaultNewEventPeriod = defaultEventPeriod
        
        let viewModel = EventDetailInputViewModelImple(
            eventTagUsecase: tagUsecase,
            calendarSettingUsecase: settingUsecase,
            eventSettingUsecase: eventSettingUsecase,
            linkPreviewFetchUsecase: StubLinkPreviewFetchUsecase(),
            daysIntervalCountUescase: StubDaysIntervalCountUsecase()
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
        |> \.repeatingEndOption .~ .until(100)
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
    
    // 입력한 값에 따라 초기 url값 제공
    func testViewModel_whenAfterPrepare_provideInitailURL() {
        // given
        let expect = expectation(description: "prepare 이후에 이전에 입혁한 url 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let urls = self.waitOutputs(expect, for: viewModel.initailURL) {
            self.prepareViewModelWithOldData(viewModel)
            
            viewModel.enter(name: "new name")
            viewModel.enter(url: "new url")
        }
        
        // then
        XCTAssertEqual(urls, ["old_url"])
    }
    
    func testViewModel_whenEnterURLAddress_checkIsValid() {
        // given
        let expect = expectation(description: "url 입력시 올바른 형식인지 검사")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let isValids = self.waitOutputs(expect, for: viewModel.isValidURLEntered) {
            self.prepareViewModelWithOldData(viewModel)
            
            viewModel.enter(url: "https://www.naver.com")
            viewModel.enter(url: "wrong url address")
            viewModel.enter(url: "https://www.google.com")
        }
        
        // then
        XCTAssertEqual(isValids, [false, true, false, true])
    }
    
    func testViewModel_whenEnterValidURL_providePreviewModel() {
        // given
        let expect = expectation(description: "올바른 형식의 url 입력시 preview 정보 제공")
        expect.expectedFulfillmentCount = 5
        let viewModel = self.makeViewModel()
        
        // when
        let models = self.waitOutputs(expect, for: viewModel.linkPreview, timeout: 3) {
            self.prepareViewModelWithOldData(viewModel)
            Task {
                try await Task.sleep(for: .milliseconds(400))
                viewModel.enter(url: "https://www.google.com")
                
                try await Task.sleep(for: .milliseconds(400))
                viewModel.enter(url: "wrong url")
                
                try await Task.sleep(for: .milliseconds(400))
                viewModel.enter(url: "https://naver.com")
            }
        }
        
        // then
        let descriptions = models.map { $0?.description }
        XCTAssertEqual(descriptions, [
            nil, nil, "desc:https://www.google.com", nil, "desc:https://naver.com"
        ])
    }
    
    func testViewModel_openEnteringURL() {
        // given
        let expect = expectation(description: "wait valid url enter")
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitFirstOutput(expect, for: viewModel.isValidURLEntered.filter { $0 }) {
            self.prepareViewModelWithOldData(viewModel)
            viewModel.enter(url: "https://www.google.com")
        }
        viewModel.openURL()
        
        // then
        XCTAssertEqual(self.spyRouter.didOpenSafariPath, "https://www.google.com")
    }
    
    // 입력한 값에 따라 초기 memo값 제공
    func testViewModel_whenAfterPrepare_provideInitailMemo() {
        // given
        let expect = expectation(description: "prepare 이후에 이전에 입혁한 memo값 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let memos = self.waitOutputs(expect, for: viewModel.initialMemo) {
            self.prepareViewModelWithOldData(viewModel)
            
            viewModel.enter(memo: "new memo")
        }
    
        // then
        XCTAssertEqual(memos, ["old_memo"])
    }
    
    func testViewModel_provideDefaultEventStartTimeWithNormalize() {
        // given
        let viewModel = self.makeViewModel()
        let calendar = Calendar(identifier: .gregorian)
        func parameterizeTest(_ currentMinutes: Int, expectMinutes: Int) {
            // given
            let now = calendar.dateBySetting(from: Date()) { $0.minute = currentMinutes }!
            
            // when
            let startDate = viewModel.startTimeDefaultDate(for: now)
            
            // then
            let newMinutes = calendar.component(.minute, from: startDate)
            XCTAssertEqual(newMinutes, expectMinutes)
        }
        
        // when + then
        parameterizeTest(40, expectMinutes: 40)
        parameterizeTest(41, expectMinutes: 45)
        parameterizeTest(43, expectMinutes: 45)
        parameterizeTest(44, expectMinutes: 45)
        parameterizeTest(45, expectMinutes: 45)
        parameterizeTest(46, expectMinutes: 50)
        parameterizeTest(49, expectMinutes: 50)
    }
    
    func testViewModel_provideDefaultEventEndtimeByEventTimePeriodSetting() {
        // given
        func parameterizeTest(
            _ defaultPeriod: EventSettings.DefaultNewEventPeriod,
            expectInterval: Int
        ) {
            // given
            let viewModel = self.makeViewModel(defaultEventPeriod: defaultPeriod)
            let now = Date()
            // when
            let endTime = viewModel.endTimeDefaultDate(from: now)
            
            // then
            let interval = endTime.timeIntervalSince(now)
            XCTAssertEqual(expectInterval, Int(interval))
        }
        
        // when + then
        parameterizeTest(.minute0, expectInterval: 60*60)
        parameterizeTest(.minute5, expectInterval: 5*60)
        parameterizeTest(.minute10, expectInterval: 10*60)
        parameterizeTest(.minute15, expectInterval: 15*60)
        parameterizeTest(.minute30, expectInterval: 30*60)
        parameterizeTest(.minute45, expectInterval: 45*60)
        parameterizeTest(.hour1, expectInterval: 60*60)
        parameterizeTest(.hour2, expectInterval: 120*60)
        parameterizeTest(.allDay, expectInterval: 60*60)
    }
}


// MARK: - test select

extension EventDetailInputViewModelTests {
    
    func testSelectTimetext() {
        // given
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
        let thisYear = self.thisYearRefDate
        let nextYear = calendar.addYear(1, from: thisYear)!
        
        // when
        let thisYearText = SelectTimeText(thisYear.timeIntervalSince1970, self.timeZone)
        let nextYearText = SelectTimeText(nextYear.timeIntervalSince1970, self.timeZone)
        let thisYearWithoutTime = SelectTimeText(thisYear.timeIntervalSince1970, self.timeZone, withoutTime: true)
        
        // then
        XCTAssertEqual(thisYearText.year, nil)
        XCTAssertEqual(thisYearText.day, thisYear.dateText(at: self.timeZone))
        XCTAssertEqual(thisYearText.time, thisYear.timeText(at: self.timeZone))
        
        XCTAssertEqual(nextYearText.year, nextYear.yearText(at: self.timeZone))
        XCTAssertEqual(nextYearText.day, nextYear.dateText(at: self.timeZone))
        XCTAssertEqual(nextYearText.time, nextYear.timeText(at: self.timeZone))
        
        XCTAssertEqual(thisYearWithoutTime.year, nil)
        XCTAssertEqual(thisYearWithoutTime.day, thisYear.dateText(at: self.timeZone))
        XCTAssertEqual(thisYearWithoutTime.time, nil)
    }
    
    func testSelectedTime_fromEventTime() {
        // given
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
        let next = self.refDate!.add(days: 3)!
        let refStart = calendar.startOfDay(for: self.refDate!)
        let nextEnd = calendar.endOfDay(for: next)!
        
        // when
        let timeAt = SelectedTime(
            .at(self.refDate!.timeIntervalSince1970), self.timeZone
        )
        let period = SelectedTime(
            self.dummy3DaysPeriod, self.timeZone
        )
        let singleAllDay = SelectedTime(
            self.dummySingleAllDayPeriod, self.timeZone
        )
        let allDays = SelectedTime(
            self.dummyAll3DaysPeriod, self.timeZone
        )
        
        // then
        XCTAssertEqual(
            timeAt, .at(.init(self.refDate.timeIntervalSince1970, self.timeZone))
        )
        XCTAssertEqual(
            period,
            .period(
                .init(self.refDate.timeIntervalSince1970, self.timeZone),
                    .init(next.timeIntervalSince1970, self.timeZone))
        )
        XCTAssertEqual(
            singleAllDay,
            .singleAllDay(.init(refStart.timeIntervalSince1970, self.timeZone, withoutTime: true))
        )
        XCTAssertEqual(
            allDays,
            .alldayPeriod(
                .init(refStart.timeIntervalSince1970, self.timeZone, withoutTime: true),
                .init(nextEnd.timeIntervalSince1970, self.timeZone, withoutTime: true)
            )
        )
    }

    
    // time + at => all day on -> 선택날짜 allday => all day off -> 이전 선택한 날짜
    func testViewModel_whenEventTimeIsTimeAtAndToggleIsAllDay_udpateSelectedTime() {
        // given
        let expect = expectation(description: "time + at => all day on -> 선택날짜 allday => all day off -> 이전 선택한 날짜")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            self.prepareViewModelWithOldData(viewModel)
            viewModel.removeEventEndTime()
            
            viewModel.toggleIsAllDay()
            viewModel.toggleIsAllDay()
        }
        
        // then
        XCTAssertEqual(times[safe: 0]??.isPeriod, true)
        XCTAssertEqual(times[safe: 1]??.isAt, true)
        XCTAssertEqual(times[safe: 2]??.isSingleAllDay, true)
        XCTAssertEqual(times[safe: 3]??.isPeriod, true)
    }
    
    // time + period(복수일) => all day on -> 선택 복수날짜 allday => all day off -> 이전 선택한 날짜
    func testViewModel_whenEventTimeIs3DaysPeriod_toggleAllDay() {
        // given
        let expect = expectation(description: "time + period(복수일) => all day on -> 선택 복수날짜 allday => all day off -> 이전 선택한 날짜")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            self.prepareViewModelWithOldData(viewModel)
            viewModel.selectEndtime(Date().add(days: 3)!)
            
            viewModel.toggleIsAllDay()
            viewModel.toggleIsAllDay()
        }
        
        // then
        XCTAssertEqual(times[safe: 0]??.isPeriod, true)
        XCTAssertEqual(times[safe: 1]??.isPeriod, true)
        XCTAssertEqual(times[safe: 2]??.isAllDayPeriod, true)
        XCTAssertEqual(times[safe: 3]??.isPeriod, true)
    }
    
    // time + period(단수일) => all day on -> 선택 단수일 allday => all day off -> 이전 선택한 날짜
    func testViewModel_whenEventTimeIsSingleDayPeriod_toggleAllDay() {
        // given
        let expect = expectation(description: "time + period(단수일) => all day on -> 선택 단수일 allday => all day off -> period")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            self.prepareViewModelWithOldData(viewModel)
            viewModel.selectEndtime(self.refDate.addingTimeInterval(60))
            viewModel.toggleIsAllDay()
            viewModel.toggleIsAllDay()
        }
        
        // then
        XCTAssertEqual(times[safe: 0]??.isPeriod, true)
        // 매일밤 11시에 돌리면 tc 꺄잘수있음
        XCTAssertEqual(times[safe: 1]??.isPeriod, true)
        XCTAssertEqual(times[safe: 2]??.isSingleAllDay, true)
        XCTAssertEqual(times[safe: 3]??.isPeriod, true)
    }
    

    func testViewModel_updateStartTime() {
        // given
        let expect = expectation(description: "시작시간 업데이트")
        expect.expectedFulfillmentCount = 9
        let viewModel = self.makeViewModel()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            self.prepareViewModelWithOldData(viewModel) // 1. 최초 period
            viewModel.selectStartTime(Date().add(days: 10)!) // 2. period 시작시간 변경 및 유효하지 않음
            viewModel.removeEventEndTime()  // 3. at으로 변경
            viewModel.selectStartTime(Date(timeIntervalSince1970: 0)) // 4. update
            
            viewModel.removeTime()  // 5. remove all
            viewModel.selectStartTime(Date(timeIntervalSince1970: 0)) // 6. at
            viewModel.toggleIsAllDay()    // 7. isSingle all day
            
            viewModel.selectEndtime(Date(timeIntervalSince1970: 0).add(days: 4)!) // 8. update all day period
            viewModel.selectStartTime(Date(timeIntervalSince1970: 0).add(days: 1)!) // 9. update startTime
        }
        
        // then
        XCTAssertEqual(times[safe: 0]??.isPeriod, true)
        XCTAssertEqual(times[safe: 1]??.isPeriod, true)
        XCTAssertEqual(times[safe: 1]??.isValid, false)
        XCTAssertEqual(times[safe: 2]??.isAt, true)
        XCTAssertEqual(times[safe: 3]??.isAt, true)
        XCTAssertEqual(times[safe: 3]??.startTime.timeIntervalSince1970, 0)
        XCTAssertEqual(times[safe: 4] ?? nil, nil)
        XCTAssertEqual(times[safe: 5]??.isAt, true)
        XCTAssertEqual(times[safe: 6]??.isSingleAllDay, true)
        XCTAssertEqual(times[safe: 7]??.isAllDayPeriod, true)
        XCTAssertEqual(times[safe: 8]??.isAllDayPeriod, true)
        XCTAssertEqual(times[safe: 8]??.startTime.timeIntervalSince1970, Date(timeIntervalSince1970: 0).add(days: 1)!.timeIntervalSince1970)
    }
    
    func testViewModel_whenChangeStartTimeAfterSelectAllDay_doNotProvideTimeText() {
        // given
        let expect = expectation(description: "시작시간 allday 선택 이후에 날짜 변경시 시간정보는 제공 안함")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            self.prepareViewModelWithOldData(viewModel) // 1. 최초 period
            viewModel.removeEventEndTime()
            viewModel.toggleIsAllDay() //2. isSingle all day
            viewModel.selectStartTime(Date(timeIntervalSince1970: 10).add(days: 1)!)
        }
        
        // then
        XCTAssertEqual(times[safe: 0]??.isPeriod, true)
        XCTAssertEqual(times[safe: 0]??.startTimeText != nil, true)
        XCTAssertEqual(times[safe: 1]??.isAt, true)
        XCTAssertEqual(times[safe: 1]??.startTimeText != nil, true)
        XCTAssertEqual(times[safe: 2]??.isSingleAllDay, true)
        XCTAssertEqual(times[safe: 2]??.startTimeText != nil, false)
        XCTAssertEqual(times[safe: 3]??.isSingleAllDay, true)
        XCTAssertEqual(times[safe: 3]??.startTimeText != nil, false)
    }
    
    func testViewModel_whenSelectTime_countDDay() {
        // given
        let expect = expectation(description: "날짜 선택 여부에 따라 d-day count")
        expect.expectedFulfillmentCount = 7
        expect.assertForOverFulfill = false
        let viewModel = self.makeViewModel()
        
        // when
        let days = self.waitOutputs(expect, for: viewModel.selectedTimeDDay) {
            self.prepareViewModelWithOldData(viewModel)
            viewModel.removeTime()
            
            viewModel.selectStartTime(Date())
        }
        
        // then
        XCTAssertEqual(days, [
            "D+4", "D-Day", "D-4",
            nil,
            "D+4", "D-Day", "D-4",
        ])
    }
    
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
            viewModel.selectEventTag(didSelected: .init(.holiday, "some", "holiday"))
        }
        
        // then
        let selectedTagIds = tags.map { $0.tagId }
        XCTAssertEqual(selectedTagIds, [.custom("some"), .holiday])
    }
    
    func testViewModel_whenSelectedTagNotExists_provideDefaultTag() {
        // given
        let expect = expectation(description: "매칭되는 태그 존재 안하는 경우 디폴트 태그 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let tag = self.waitFirstOutput(expect, for: viewModel.selectedTag) {
            let basic = self.dummyPreviousBasic |> \.eventTagId .~ .custom("not_exists")
            viewModel.prepared(basic: basic, additional: self.dummyPreviousAddition)
        }
        
        // then
        XCTAssertEqual(tag?.tagId, .default)
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
    
    func testViewModel_whenRepeatTimeSelected_updatePeriodText() {
        // given
        let expect = expectation(description: "이벤트 반복 옵션 선택 이후에 반복시간 기간정보 업데이트")
        expect.expectedFulfillmentCount = 6
        let viewModel = self.makeViewModel()
        let dummy = EventRepeatingTimeSelectResult(
            text: "Everyday".localized(),
            repeating: EventRepeating(
                repeatingStartTime: Date(timeIntervalSince1970: 0).timeIntervalSince1970,
                repeatOption: EventRepeatingOptions.EveryDay()
            )
        )
        let dummyWithEndTime = EventRepeatingTimeSelectResult(
            text: dummy.text,
            repeating: dummy.repeating |> \.repeatingEndOption .~ .until(
                Date(timeIntervalSince1970: 0).add(days: 1)!.timeIntervalSince1970
            )
        )
        
        let dummyWithEndCount = EventRepeatingTimeSelectResult(
            text: dummy.text,
            repeating: dummy.repeating |> \.repeatingEndOption .~ .count(100)
        )
        
        // when
        let periods = self.waitOutputs(expect, for: viewModel.repeatOptionPeriod) {
            self.prepareViewModelWithOldData(viewModel)
            
            viewModel.selectRepeatOption()
            viewModel.selectEventRepeatOption(didSelect: dummy) // on
            
            viewModel.selectRepeatOption()
            viewModel.selectEventRepeatOptionNotRepeat() // off
            
            viewModel.selectRepeatOption()
            viewModel.selectEventRepeatOption(didSelect: dummyWithEndTime) // on
            
            viewModel.selectRepeatOption()
            viewModel.selectEventRepeatOption(didSelect: dummyWithEndCount)
            
            viewModel.removeTime()
        }
        
        // then
        XCTAssertEqual(periods, [
            "Jan 1, 1970 ~ Jan 1, 1970",
            "Jan 1, 1970 ~ ",
            nil,
            "Jan 1, 1970 ~ Jan 2, 1970",
            "Starting Jan 1, 1970 100 times",
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
        viewModel.selectEventTag(
            didSelected: SelectedTag(DefaultEventTag.default("default"))
        )
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
        selectTime: Date, with initalOption: EventRepeating?,
        listener: (any SelectEventRepeatOptionSceneListener)?
    ) {
        self.didRouteToEventRepeatOptionSelect = true
    }
    
    var didRouteToSelectEventTag: Bool?
    func routeToEventTagSelect(
        currentSelectedTagId: EventTagId,
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


private extension SelectedTime {
    
    var isAt: Bool {
        guard case .at = self else { return false }
        return true
    }
    
    var isPeriod: Bool {
        guard case .period = self else { return false }
        return true
    }
    
    var isSingleAllDay: Bool {
        guard case .singleAllDay = self else { return false }
        return true
    }
    
    var isAllDayPeriod: Bool {
        guard case .alldayPeriod = self else { return false }
        return true
    }
    
    var startTimeText: String? {
        switch self {
        case .at(let time): return time.time
        case .period(let start, _): return start.time
        case .singleAllDay(let time): return time.time
        case .alldayPeriod(let start, _): return start.time
        }
    }
    
    var startTime: Date {
        switch self {
        case .at(let time): return time.date
        case .period(let start, _): return start.date
        case .singleAllDay(let time): return time.date
        case .alldayPeriod(let start, _): return start.date
        }
    }
    
    var endTime: Date? {
        switch self {
        case .period(_, let end): return end.date
        case .alldayPeriod(_, let end): return end.date
        default: return nil
        }
    }
}
