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
    private var spyRouter: SpyRouter!
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
        shouldFailSaveDetailData: Bool = false
    ) -> AddEventViewModelImple {
        
        let tagUsecase = StubEventTagUsecase()
        tagUsecase.stubLatestUsecaseEventTag = latestTagExists ? .init(uuid: "latest", name: "some", colorHex: "some") : nil
        tagUsecase.prepare()
        
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        
        let viewModel = AddEventViewModelImple(
            isTodo: false,
            todoUsecase: self.spyTodoUsecase,
            scheduleUsecase: self.spyScheduleUsecase,
            eventTagUsease: tagUsecase,
            calendarSettingUsecase: settingUsecase,
            eventDetailDataUsecase: self.spyEventDetailDataUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
    
    private var defaultCurrentAndNextHourSelectTime: SelectedTime {
        let now = Date(); let next = now.addingTimeInterval(3600)
        return .period(
            .init(now.timeIntervalSince1970, self.timeZone),
            .init(next.timeIntervalSince1970, self.timeZone)
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
    
    // 최초에 현재시간 기준 현재~현재+1h로 시간 반환
    func testViewModel_initialEventTimeIsPeriodFromCurrentToNextHour() {
        // given
        let expect = expectation(description: "최초에 현재시간 기준 현재~현재+1h로 시간 반환")
        let viewModel = self.makeViewModel()
        
        // when
        let time = self.waitFirstOutput(expect, for: viewModel.selectedTime.dropFirst()) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(time, self.defaultCurrentAndNextHourSelectTime)
    }
    
    // todo여부 토글
    func testViewModel_updateIsTodo() {
        // given
        let expect = expectation(description: "todo여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isTodos = self.waitOutputs(expect, for: viewModel.isTodo) {
            viewModel.prepare()
            viewModel.toggleIsTodo()
            viewModel.toggleIsTodo()
        }
        
        // then
        XCTAssertEqual(isTodos, [false, true, false])
    }
    
    // 최초에 가장 마지막에 사용했던 태그값 반환
    func testViewModel_whenLatestUsedTagExists_provideSelectedTagAsLatestUsed() {
        // given
        let expect = expectation(description: "최초에 가장 마지막에 사용했던 태그값 반환")
        let viewModel = self.makeViewModel(latestTagExists: true)
        
        // when
        let tag = self.waitFirstOutput(expect, for: viewModel.selectedTag) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(tag?.tagId, .custom("latest"))
    }
    
    func testViewModel_whenLatestUsedTagNotExists_provideInitialSelectedTagIsDefault() {
        // given
        let expect = expectation(description: "마지막으로 사용했던 태그 존재하지 않으면 기본태그 반환")
        let viewModel = self.makeViewModel(latestTagExists: false)
        
        // when
        let tag = self.waitFirstOutput(expect, for: viewModel.selectedTag) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(tag?.tagId, .default)
    }
}


// MARK: - select

extension AddEventViewModelImpleTests {
    
    func testSelectTimetext() {
        // given
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
        let thisYear = self.refDate!
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
    
    // at -> SelectedTime
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
    
    // 시간 선택 -> 선택 이후 선택된 시간 업데이트
    func testViewModel_whenAfterSelectTime_updateSelectedTime() {
        // given
        let expect = expectation(description: "기간 선택 이후에 선택된 날짜 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        viewModel.toggleIsTodo()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            viewModel.prepare()
            viewModel.removeTime()
        }
        
        // then
        XCTAssertEqual(times, [
            nil,
            self.defaultCurrentAndNextHourSelectTime,
            nil
        ])
    }
    
    // time + at => all day on -> 선택날짜 allday => all day off -> 이전 선택한 날짜
    func testViewModel_whenEventTimeIsTimeAtAndToggleIsAllDay_udpateSelectedTime() {
        // given
        let expect = expectation(description: "time + at => all day on -> 선택날짜 allday => all day off -> 이전 선택한 날짜")
        expect.expectedFulfillmentCount = 5
        let viewModel = self.makeViewModel()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            viewModel.prepare()
            viewModel.removeEventEndTime()
            
            viewModel.toggleIsAllDay()
            viewModel.toggleIsAllDay()
        }
        
        // then
        XCTAssertEqual(times[safe: 0] ?? nil, nil)
        XCTAssertEqual(times[safe: 1]??.isPeriod, true)
        XCTAssertEqual(times[safe: 2]??.isAt, true)
        XCTAssertEqual(times[safe: 3]??.isSingleAllDay, true)
        XCTAssertEqual(times[safe: 4]??.isPeriod, true)
    }
    
    // time + period(복수일) => all day on -> 선택 복수날짜 allday => all day off -> 이전 선택한 날짜
    func testViewModel_whenEventTimeIs3DaysPeriod_toggleAllDay() {
        // given
        let expect = expectation(description: "time + period(복수일) => all day on -> 선택 복수날짜 allday => all day off -> 이전 선택한 날짜")
        expect.expectedFulfillmentCount = 5
        let viewModel = self.makeViewModel()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            viewModel.prepare()
            viewModel.selectEndtime(Date().add(days: 3)!)
            
            viewModel.toggleIsAllDay()
            viewModel.toggleIsAllDay()
        }
        
        // then
        XCTAssertEqual(times[safe: 0] ?? nil, nil)
        XCTAssertEqual(times[safe: 1]??.isPeriod, true)
        XCTAssertEqual(times[safe: 2]??.isPeriod, true)
        XCTAssertEqual(times[safe: 3]??.isAllDayPeriod, true)
        XCTAssertEqual(times[safe: 4]??.isPeriod, true)
    }
    
    // time + period(단수일) => all day on -> 선택 단수일 allday => all day off -> 이전 선택한 날짜
    func testViewModel_whenEventTimeIsSingleDayPeriod_toggleAllDay() {
        // given
        let expect = expectation(description: "time + period(단수일) => all day on -> 선택 단수일 allday => all day off -> period")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            viewModel.prepare()
            
            viewModel.toggleIsAllDay()
            viewModel.toggleIsAllDay()
        }
        
        // then
        XCTAssertEqual(times[safe: 0] ?? nil, nil)
        XCTAssertEqual(times[safe: 1]??.isPeriod, true)
        XCTAssertEqual(times[safe: 2]??.isSingleAllDay, true)
        XCTAssertEqual(times[safe: 3]??.isPeriod, true)
    }
    

    func testViewModel_updateStartTime() {
        // given
        let expect = expectation(description: "시작시간 업데이트")
        expect.expectedFulfillmentCount = 10
        let viewModel = self.makeViewModel()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            viewModel.prepare() // 1. 최초 period
            viewModel.selectStartTime(Date().add(days: 1)!) // 2. period 시작시간 변경 및 유효하지 않음
            viewModel.removeEventEndTime()  // 3. at으로 변경
            viewModel.selectStartTime(Date(timeIntervalSince1970: 0)) // 4. update
            
            viewModel.removeTime()  // 5. remove all
            viewModel.selectStartTime(Date(timeIntervalSince1970: 0)) // 6. at
            viewModel.toggleIsAllDay()    // 7. isSingle all day
            
            viewModel.selectEndtime(Date(timeIntervalSince1970: 0).add(days: 4)!) // 8. update all day period
            viewModel.selectStartTime(Date(timeIntervalSince1970: 0).add(days: 1)!) // 9. update startTime
        }
        
        // then
        XCTAssertEqual(times[safe: 0] ?? nil, nil)
        XCTAssertEqual(times[safe: 1]??.isPeriod, true)
        XCTAssertEqual(times[safe: 2]??.isPeriod, true)
        XCTAssertEqual(times[safe: 2]??.isValid, false)
        XCTAssertEqual(times[safe: 3]??.isAt, true)
        XCTAssertEqual(times[safe: 4]??.isAt, true)
        XCTAssertEqual(times[safe: 4]??.startTime.timeIntervalSince1970, 0)
        XCTAssertEqual(times[safe: 5] ?? nil, nil)
        XCTAssertEqual(times[safe: 6]??.isAt, true)
        XCTAssertEqual(times[safe: 7]??.isSingleAllDay, true)
        XCTAssertEqual(times[safe: 8]??.isAllDayPeriod, true)
        XCTAssertEqual(times[safe: 9]??.isAllDayPeriod, true)
        XCTAssertEqual(times[safe: 9]??.startTime.timeIntervalSince1970, Date(timeIntervalSince1970: 0).add(days: 1)!.timeIntervalSince1970)
    }
    
    // 태그 선택
    func testViewModel_selectEventTag() {
        // given
        let expect = expectation(description: "이벤트 태그 선택")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel(latestTagExists: true)
        
        // when
        let tags = self.waitOutputs(expect, for: viewModel.selectedTag) {
            viewModel.prepare()
            viewModel.selectEventTag()
            viewModel.selectEventTag(didSelected: .init(.holiday, "some", .holiday))
        }
        
        // then
        let selectedTagIds = tags.map { $0.tagId }
        XCTAssertEqual(selectedTagIds, [.custom("latest"), .holiday])
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
            "not repeat".localized(),
            "Everyday".localized(),
            "not repeat".localized(),
            "Everyday".localized(),
            "not repeat".localized(),
        ])
    }
    
    // 장소 선택
}

// MARK: - save

extension AddEventViewModelImpleTests {
    
    // todo의 경우 이름만 입력하면 저장 가능해짐
    func testViewModel_whenMakeTodo_isSavableWhenEnterName() {
        // given
        let expect = expectation(description: "todo의 경우 이름만 입력하면 저장 가능해짐")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let isSavables = self.waitOutputs(expect, for: viewModel.isSavable) {
            viewModel.toggleIsTodo()
            viewModel.enter(name: "todo name")
        }
        
        // then
        XCTAssertEqual(isSavables, [false, true])
    }
    
    // schedule event의 경우 이름 및 시간이 입력되어야함
    func testViewModel_whenMakeScheduleEvent_isSavableWhenEnterNameAndSelectTime() {
        // given
        let expect = expectation(description: "schedule event의 경우 이름 및 시간이 입력되어야함")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let isSavables = self.waitOutputs(expect, for: viewModel.isSavable) {
            viewModel.enter(name: "schedule name")
            viewModel.selectStartTime(self.refDate)
        }
        
        // then
        XCTAssertEqual(isSavables, [false, true])
    }
    
    private func enterInfo(_ viewModel: AddEventViewModelImple) {
        viewModel.removeEventEndTime()
        viewModel.selectStartTime(Date(timeIntervalSince1970: 100))
        viewModel.selectEventRepeatOption(
            didSelect: .init(
                text: "some",
                repeating: .init(repeatingStartTime: 100, repeatOption: EventRepeatingOptions.EveryDay()))
        )
        viewModel.selectEventTag(didSelected: .init(.custom("some"), "tag", .custom(hex: "hex")))
        viewModel.enter(url: "url")
        viewModel.enter(memo: "memo")
    }
    
    // todo 저장 완료 이후에 토스트 노출 + 화면 닫음
    func testViewModel_saveTodo() {
        // given
        let expect = expectation(description: "todo 저장 완료 이후에 토스트 노출 + 화면 닫음")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            viewModel.enter(name: "todo")
            viewModel.toggleIsTodo()
            self.enterInfo(viewModel)
            
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "[TODO] todo saved".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let madeParams = self.spyTodoUsecase.didMakeTodoWithParams
        XCTAssertEqual(madeParams?.name, "todo")
        XCTAssertEqual(madeParams?.eventTagId, .custom("some"))
        XCTAssertEqual(madeParams?.time, .at(100))
        XCTAssertEqual(madeParams?.repeating, .init(repeatingStartTime: 100, repeatOption: EventRepeatingOptions.EveryDay()) )
    }
    
    // scheudle 저장
    func testViewModel_saveScheduleEvent() {
        // given
        let expect = expectation(description: "schedule 저장 완료 이후에 토스트 노출 + 화면 닫음")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            viewModel.enter(name: "schedule")
            self.enterInfo(viewModel)
            
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "[TODO] schedule saved".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
        
        let madeParams = self.spyScheduleUsecase.didMakeScheduleParams
        XCTAssertEqual(madeParams?.name, "schedule")
        XCTAssertEqual(madeParams?.eventTagId, .custom("some"))
        XCTAssertEqual(madeParams?.time, .at(100))
        XCTAssertEqual(madeParams?.repeating, .init(repeatingStartTime: 100, repeatOption: EventRepeatingOptions.EveryDay()) )
    }
    
    // 이벤트 저장 이후에 메타데이터도 저장함
    func testViewModel_whenAfterSaveTodo_saveDetailData() {
        // given
        let expect = expectation(description: "todo 저장 완료 이후에 event detail data 저장")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            viewModel.enter(name: "todo")
            viewModel.toggleIsTodo()
            self.enterInfo(viewModel)
            
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
        let viewModel = self.makeViewModel()
        // when
        let isSavings = self.waitOutputs(expect, for: viewModel.isSaving) {
            viewModel.enter(name: "schedule")
            self.enterInfo(viewModel)
            
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
            viewModel.enter(name: "todo")
            viewModel.toggleIsTodo()
            self.enterInfo(viewModel)
            
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isSavings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "[TODO] todo saved".localized())
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }
}

private class SpyRouter: BaseSpyRouter, AddEventRouting, @unchecked Sendable {
    
    var didRouteToEventRepeatOptionSelect: Bool?
    func routeToEventRepeatOptionSelect(
        startTime: Date, with initalOption: EventRepeating?
    ) {
        self.didRouteToEventRepeatOptionSelect = true
    }
    
    var didRouteToSelectEventTag: Bool?
    func routeToEventTagSelect(currentSelectedTagId: AllEventTagId) {
        self.didRouteToSelectEventTag = true
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
