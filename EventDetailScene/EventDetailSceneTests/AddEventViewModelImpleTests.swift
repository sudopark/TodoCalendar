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
    private var spyRouter: SpyRouter!
    private var refDate: Date!
    private var timeZone: TimeZone {
        return TimeZone(abbreviation: "KST")!
    }
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
        let compos = DateComponents(year: 2023, month: 9, day: 18, hour: 4, minute: 44)
        self.refDate = calendar.date(from: compos)
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.refDate = nil
    }
    
    private func makeViewModel(
        latestTagExists: Bool = true
    ) -> AddEventViewModelImple {
        
        let todoUsecase = StubTodoEventUsecase()
        let scheduleUsecase = StubScheduleEventUsecase()
        let tagUsecase = StubEventTagUsecase()
        tagUsecase.stubLatestUsecaseEventTag = latestTagExists ? .init(uuid: "latest", name: "some", colorHex: "some") : nil
        tagUsecase.prepare()
        
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        
        let viewModel = AddEventViewModelImple(
            todoUsecase: todoUsecase,
            scheduleUsecase: scheduleUsecase,
            eventTagUsease: tagUsecase,
            calendarSettingUsecase: settingUsecase
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
        let time = self.waitFirstOutput(expect, for: viewModel.selectedTime)
        
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
        let tag = self.waitFirstOutput(expect, for: viewModel.selectedTag)
        
        // then
        XCTAssertEqual(tag?.tagId, .custom("latest"))
    }
    
    func testViewModel_whenLatestUsedTagNotExists_provideInitialSelectedTagIsDefault() {
        // given
        let expect = expectation(description: "마지막으로 사용했던 태그 존재하지 않으면 기본태그 반환")
        let viewModel = self.makeViewModel(latestTagExists: false)
        
        // when
        let tag = self.waitFirstOutput(expect, for: viewModel.selectedTag)
        
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
            .singleAllDay(.init(refStart.timeIntervalSince1970, self.timeZone))
        )
        XCTAssertEqual(
            allDays,
            .alldayPeriod(
                .init(refStart.timeIntervalSince1970, self.timeZone),
                .init(nextEnd.timeIntervalSince1970, self.timeZone)
            )
        )
    }
    
    // 시간 선택 -> 선택 이후 선택된 시간 업데이트
    func testViewModel_whenAfterSelectTime_updateSelectedTime() {
        // given
        let expect = expectation(description: "기간 선택 이후에 선택된 날짜 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        viewModel.toggleIsTodo()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            viewModel.eventTimeSelect(didSelect: nil)
        }
        
        // then
        XCTAssertEqual(times, [
            self.defaultCurrentAndNextHourSelectTime, 
            nil
        ])
    }
    
    // time + at => all day on -> 선택날짜 allday => all day off -> 이전 선택한 날짜
    func testViewModel_whenEventTimeIsTimeAtAndToggleIsAllDay_udpateSelectedTime() {
        // given
        let expect = expectation(description: "time + at => all day on -> 선택날짜 allday => all day off -> 이전 선택한 날짜")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            viewModel.eventTimeSelect(didSelect: .at(self.refDate!.timeIntervalSince1970))
            
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
            viewModel.eventTimeSelect(didSelect: self.dummy3DaysPeriod)
            
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
            viewModel.eventTimeSelect(didSelect: self.dummySingleDayPeriod)
            
            viewModel.toggleIsAllDay()
            viewModel.toggleIsAllDay()
        }
        
        // then
        XCTAssertEqual(times[safe: 0]??.isPeriod, true)
        XCTAssertEqual(times[safe: 1]??.isPeriod, true)
        XCTAssertEqual(times[safe: 2]??.isSingleAllDay, true)
        XCTAssertEqual(times[safe: 3]??.isPeriod, true)
    }
    
    // 태그 선택
    
    // 반복옵션 선택
    
    // 장소 선택
}

// MARK: - save

extension AddEventViewModelImpleTests {
    
    // todo의 경우 이름만 입력하면 저장 가능해짐
    
    // schedule event의 경우 이름 및 시간이 입력되어야함
    
    // todo 저장
    
    // scheudle 저장
    
    // 저장시에 저장중임을 알림
}

private class SpyRouter: BaseSpyRouter, AddEventRouting, @unchecked Sendable {
    
    
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
}
