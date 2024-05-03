//
//  SelectEventTimeViewModelImpleTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 5/4/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
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


class SelectEventTimeViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyListener: SpyListener!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyListener = .init()
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
        let compos = DateComponents(year: 2023, month: 9, day: 18, hour: 4, minute: 44)
        self.refDate = calendar.date(from: compos)
    }
    
    override func tearDownWithError() throws {
        self.spyListener = nil
        self.cancelBag = nil
        self.refDate = nil
    }
    
    private var refDate: Date!
    private var timeZone: TimeZone {
        return TimeZone(abbreviation: "KST")!
    }
    
    private var thisYearRefDate: Date {
        let calenar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
        let year = calenar.component(.year, from: Date())
        return calenar.date(bySetting: .year, value: year, of: self.refDate)!
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
    
    private func makeViewModel() -> SelectEventTimeViewModelImple {
        let previousTime = SelectedTime(
            self.dummy3DaysPeriod, self.timeZone
        )
        let viewModel = SelectEventTimeViewModelImple(
            startWith: previousTime, at: self.timeZone
        )
        viewModel.listener = self.spyListener
        return viewModel
    }
}

extension SelectEventTimeViewModelImpleTests {
    
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
}

extension SelectEventTimeViewModelImpleTests {
    
    // time + at => all day on -> 선택날짜 allday => all day off -> 이전 선택한 날짜
    func testViewModel_whenEventTimeIsTimeAtAndToggleIsAllDay_udpateSelectedTime() {
        // given
        let expect = expectation(description: "time + at => all day on -> 선택날짜 allday => all day off -> 이전 선택한 날짜")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            viewModel.removeEndTime()
            
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
            viewModel.selectEndTime(Date().add(days: 3)!)
            
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
            viewModel.selectEndTime(self.refDate.addingTimeInterval(60))
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
            // 1. 최초 period
            viewModel.selectStartTime(Date().add(days: 10)!) // 2. period 시작시간 변경 및 유효하지 않음
            viewModel.removeEndTime()  // 3. at으로 변경
            viewModel.selectStartTime(Date(timeIntervalSince1970: 0)) // 4. update
            
            viewModel.removeEventTime()  // 5. remove all
            viewModel.selectStartTime(Date(timeIntervalSince1970: 0)) // 6. at
            viewModel.toggleIsAllDay()    // 7. isSingle all day
            
            viewModel.selectEndTime(Date(timeIntervalSince1970: 0).add(days: 4)!) // 8. update all day period
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
}

private final class SpyRouter: BaseSpyRouter, SelectEventTimeRouting, @unchecked Sendable { }

private final class SpyListener: SelectEventTimeSceneListener {
    
    var didSelectedtime: SelectedTime?
    func select(eventTime: SelectedTime?) {
        self.didSelectedtime = eventTime
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
