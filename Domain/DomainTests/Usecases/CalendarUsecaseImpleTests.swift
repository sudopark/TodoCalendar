//
//  CalendarUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/06/26.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import Domain


class CalendarUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubSettingUsecase: StubCalendarSettingUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubSettingUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubSettingUsecase = nil
    }
    
    private func makeUsecaseWithStub(
        firstWeekDay: DayOfWeeks = .sunday
    ) -> CalendarUsecaseImple {
        self.stubSettingUsecase.updateFirstWeekDay(firstWeekDay)
        self.stubSettingUsecase.selectTimeZone(TimeZone(abbreviation: "KST")!)
        
        let holidayUsecase = StubHolidayUsecase(
            holidays: [2023: [
                .init(dateString: "2023-01-01", localName: "신정", name: "신정"),
                .init(dateString: "2023-01-21", localName: "설날", name: "설날"),
                .init(dateString: "2023-01-22", localName: "설날", name: "설날"),
                .init(dateString: "2023-01-23", localName: "설날", name: "설날"),
                .init(dateString: "2023-01-24", localName: "설날(대체)", name: "설날(대체)"),
                .init(dateString: "2023-03-01", localName: "삼일절", name: "삼일절"),
                .init(dateString: "2023-05-05", localName: "어린이날", name: "어린이날"),
                .init(dateString: "2023-05-27", localName: "부처님오신날", name: "부처님오신날"),
                .init(dateString: "2023-06-06", localName: "현충일", name: "현충일"),
                .init(dateString: "2023-06-06", localName: "현충일", name: "현충일"),
                .init(dateString: "2023-08-15", localName: "광복절", name: "광복절"),
                .init(dateString: "2023-09-28", localName: "추석", name: "추석"),
                .init(dateString: "2023-09-29", localName: "추석", name: "추석"),
                .init(dateString: "2023-09-30", localName: "추석", name: "추석"),
                .init(dateString: "2023-10-03", localName: "개천절", name: "개천절"),
                .init(dateString: "2023-10-09", localName: "한글날", name: "한글날"),
                .init(dateString: "2023-12-25", localName: "크리스마스", name: "크리스마스")
            ]]
        )
        
        
        return CalendarUsecaseImple(
            calendarSettingUsecase: self.stubSettingUsecase,
            holidayUsecase: holidayUsecase
        )
    }
    
    private func changeWeekFirstDay(_ newValue: DayOfWeeks) {
        self.stubSettingUsecase.updateFirstWeekDay(newValue)
    }
}

extension CalendarUsecaseImpleTests {
    
    private func assertCalendarComponents(
        _ components: CalendarComponent?,
        _ expectedComponets: [[(Int, Int)]]
    ) {
        let expectedMonths = expectedComponets.map { weeks in weeks.map { $0.0 } }
        let expectedDays = expectedComponets.map { weeks in weeks.map { $0.1 } }
        
        let months = components?.weeks.map { weeks in weeks.days.map { $0.month } }
        let days = components?.weeks.map { weeks in weeks.days.map { $0.day } }
        
        XCTAssertEqual(months, expectedMonths)
        XCTAssertEqual(days, expectedDays)
    }
    
    func testUsecase_provide2023_1_withSundayAsWeekStart() {
        // given
        let expect = expectation(description: "일요일부터 주 시작 -> 2023년 1월 => 1월1일 ~ 2월 4일")
        let usecase = self.makeUsecaseWithStub()
        
        // when
        let source = usecase.components(for: 01, of: 2023, at: .init(abbreviation: "KST")!)
        let components = self.waitFirstOutput(expect, for: source)
        
        // then
        self.assertCalendarComponents(components, [
            [(1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7)],
            [(1, 8), (1, 9), (1, 10), (1, 11), (1, 12), (1, 13), (1, 14)],
            [(1, 15), (1, 16), (1, 17), (1, 18), (1, 19), (1, 20), (1, 21)],
            [(1, 22), (1, 23), (1, 24), (1, 25), (1, 26), (1, 27), (1, 28)],
            [(1, 29), (1, 30), (1, 31), (2, 1), (2, 2), (2, 3), (2, 4)]
        ])
    }
    
    func testUsecase_provide2023_2_withSundayAsWeekStart() {
        // given
        let expect = expectation(description: "일요일부터 주 시작 -> 2023년 2월 => 1월 29일 ~ 3월 4일")
        let usecase = self.makeUsecaseWithStub()
        
        // when
        let source = usecase.components(for: 02, of: 2023, at: .init(abbreviation: "KST")!)
        let components = self.waitFirstOutput(expect, for: source)
        
        // then
        self.assertCalendarComponents(components, [
            [(1, 29), (1, 30), (1, 31), (2, 1), (2, 2), (2, 3), (2, 4)],
            [(2, 5), (2, 6), (2, 7), (2, 8), (2, 9), (2, 10), (2, 11)],
            [(2, 12), (2, 13), (2, 14), (2, 15), (2, 16), (2, 17), (2, 18)],
            [(2, 19), (2, 20), (2, 21), (2, 22), (2, 23), (2, 24), (2, 25)],
            [(2, 26), (2, 27), (2, 28), (3, 1), (3, 2), (3, 3), (3, 4)],
        ])
    }
    
    func testUsecase_provide2023_4_withSundayAsWeekStart() {
        // given
        let expect = expectation(description: "일요일부터 주 시작 -> 2023년 4월 => 3월 26일 ~ 5월 6일")
        let usecase = self.makeUsecaseWithStub()
        
        // when
        let source = usecase.components(for: 04, of: 2023, at: .init(abbreviation: "KST")!)
        let components = self.waitFirstOutput(expect, for: source)
        
        // then
        self.assertCalendarComponents(components, [
            [(3, 26), (3, 27), (3, 28), (3, 29), (3, 30), (3, 31), (4, 1)],
            [(4, 2), (4, 3), (4, 4), (4, 5), (4, 6), (4, 7), (4, 8)],
            [(4, 9), (4, 10), (4, 11), (4, 12), (4, 13), (4, 14), (4, 15)],
            [(4, 16), (4, 17), (4, 18), (4, 19), (4, 20), (4, 21), (4, 22)],
            [(4, 23), (4, 24), (4, 25), (4, 26), (4, 27), (4, 28), (4, 29)],
            [(4, 30), (5, 1), (5, 2), (5, 3), (5, 4), (5, 5), (5, 6)],
        ])
    }
    
    func testUsecase_provide2023_5_withSundayAsWeekStart() {
        // given
        let expect = expectation(description: "일요일부터 주 시작 -> 2023년 5월 => 4월 30일 ~ 6월 3일")
        let usecase = self.makeUsecaseWithStub()
        
        // when
        let source = usecase.components(for: 05, of: 2023, at: .init(abbreviation: "KST")!)
        let components = self.waitFirstOutput(expect, for: source)
        
        // then
        self.assertCalendarComponents(components, [
            [(4, 30), (5, 1), (5, 2), (5, 3), (5, 4), (5, 5), (5, 6)],
            [(5, 7), (5, 8), (5, 9), (5, 10), (5, 11), (5, 12), (5, 13)],
            [(5, 14), (5, 15), (5, 16), (5, 17), (5, 18), (5, 19), (5, 20)],
            [(5, 21), (5, 22), (5, 23), (5, 24), (5, 25), (5, 26), (5, 27)],
            [(5, 28), (5, 29), (5, 30), (5, 31), (6, 1), (6, 2), (6, 3)],
        ])
    }
    
    func testUsecase_provide2023_5_withMondayAsWeekStart() {
        // given
        let expect = expectation(description: "월요일부터 주 시작 -> 2023년 5월 => 5월 1일 ~ 6월 4일")
        let usecase = self.makeUsecaseWithStub()
        
        // when
        let source = usecase.components(for: 05, of: 2023, at: .init(abbreviation: "KST")!)
        let components = self.waitFirstOutput(expect, for: source.dropFirst()) {
            self.changeWeekFirstDay(.monday)
        }
        
        // then
        self.assertCalendarComponents(components, [
            [(5, 1), (5, 2), (5, 3), (5, 4), (5, 5), (5, 6), (5, 7)],
            [(5, 8), (5, 9), (5, 10), (5, 11), (5, 12), (5, 13), (5, 14)],
            [(5, 15), (5, 16), (5, 17), (5, 18), (5, 19), (5, 20), (5, 21)],
            [(5, 22), (5, 23), (5, 24), (5, 25), (5, 26), (5, 27), (5, 28)],
            [(5, 29), (5, 30), (5, 31), (6, 1), (6, 2), (6, 3), (6, 4)],
        ])
    }
    
    func testUsecase_provide2023_12_withMondayAsWeekStart() {
        // given
        let expect = expectation(description: "월요일부터 주 시작 -> 2023년 12월 => 11월 27일 ~ 12월 31일")
        let usecase = self.makeUsecaseWithStub()
        
        // when
        let source = usecase.components(for: 12, of: 2023, at: .init(abbreviation: "KST")!)
        let components = self.waitFirstOutput(expect, for: source.dropFirst()) {
            self.changeWeekFirstDay(.monday)
        }
        
        // then
        self.assertCalendarComponents(components, [
            [(11, 27), (11, 28), (11, 29), (11, 30), (12, 1), (12, 2), (12, 3)],
            [(12, 4), (12, 5), (12, 6), (12, 7), (12, 8), (12, 9), (12, 10)],
            [(12, 11), (12, 12), (12, 13), (12, 14), (12, 15), (12, 16), (12, 17)],
            [(12, 18), (12, 19), (12, 20), (12, 21), (12, 22), (12, 23), (12, 24)],
            [(12, 25), (12, 26), (12, 27), (12, 28), (12, 29), (12, 30), (12, 31)],
        ])
    }
    
    func testUsecase_provide2023_12_withSaturdayAsWeekStart() {
        // given
        let expect = expectation(description: "토요일부터 주 시작 -> 2023년 12월 => 11월 25일 ~ 1월 5일")
        let usecase = self.makeUsecaseWithStub()
        
        // when
        let source = usecase.components(for: 12, of: 2023, at: .init(abbreviation: "KST")!)
        let components = self.waitFirstOutput(expect, for: source.dropFirst()) {
            self.changeWeekFirstDay(.saturday)
        }
        
        // then
        self.assertCalendarComponents(components, [
            [(11, 25), (11, 26), (11, 27), (11, 28), (11, 29), (11, 30), (12, 1)],
            [(12, 2), (12, 3), (12, 4), (12, 5), (12, 6), (12, 7), (12, 8)],
            [(12, 9), (12, 10), (12, 11), (12, 12), (12, 13), (12, 14), (12, 15)],
            [(12, 16), (12, 17), (12, 18), (12, 19), (12, 20), (12, 21), (12, 22)],
            [(12, 23), (12, 24), (12, 25), (12, 26), (12, 27), (12, 28), (12, 29)],
            [(12, 30), (12, 31), (1, 1), (1, 2), (1, 3), (1, 4), (1, 5)]
        ])
    }
}

extension CalendarUsecaseImpleTests {
    
    func testUsecase_whenProvideCalendarComponents_provideHolidayInfo() {
        // given
        let expect = expectation(description: "달력정보 제공시에 공휴일 정보 같이 제공")
        let usecase = self.makeUsecaseWithStub()
        
        // when
        let source = usecase.components(for: 09, of: 2023, at: .init(abbreviation: "KST")!)
        let components = self.waitFirstOutput(expect, for: source.dropFirst()) {
            self.changeWeekFirstDay(.saturday)
        }
        
        // then
        let holidayExistDays = components?.weeks.flatMap { $0.days }
            .filter { $0.holiday != nil }
        XCTAssertEqual(holidayExistDays, [
            .init(year: 2023, month: 09, day: 28, weekDay: 5) |> \.holiday .~ .init(dateString: "2023-09-28", localName: "추석", name: "추석"),
            .init(year: 2023, month: 09, day: 29, weekDay: 6) |> \.holiday .~ .init(dateString: "2023-09-29", localName: "추석", name: "추석"),
            .init(year: 2023, month: 09, day: 30, weekDay: 7) |> \.holiday .~ .init(dateString: "2023-09-30", localName: "추석", name: "추석"),
            .init(year: 2023, month: 10, day: 03, weekDay: 3) |> \.holiday .~ .init(dateString: "2023-10-03", localName: "개천절", name: "개천절"),
        ])
    }
}


extension CalendarUsecaseImpleTests {
    
    func testUsecase_provide_currentDayInfo() {
        // given
        let expect = expectation(description: "현재 날짜 정보 제공")
        let usecase = self.makeUsecaseWithStub()
        
        // when
        let current = self.waitFirstOutput(expect, for: usecase.currentDay)
        
        // then
        let now = Date(); let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ .init(abbreviation: "KST")!
        XCTAssertEqual(current?.year, calendar.component(.year, from: now))
        XCTAssertEqual(current?.month, calendar.component(.month, from: now))
        XCTAssertEqual(current?.day, calendar.component(.day, from: now))
    }
    
    func testUsecase_whenTimeZoneChanged_updateCurrentDay() {
        // given
        let expect = expectation(description: "timeZone 변경시에 현재 날짜도 업데이트")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecaseWithStub()
        
        // when
        let currents = self.waitOutputs(expect, for: usecase.currentDay) {
            self.stubSettingUsecase.selectTimeZone(TimeZone(abbreviation: "PDT")!)
        }
        
        // then
        XCTAssertEqual(currents.count, 2)
    }
}
