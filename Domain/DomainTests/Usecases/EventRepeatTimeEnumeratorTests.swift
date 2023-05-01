//
//  EventRepeatTimeEnumeratorTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/04/25.
//

import XCTest
import Prelude
import Optics
import UnitTestHelpKit

@testable import Domain


class BaseEventRepeatTimeEnumeratorTests: BaseTestCase {
    
    func makeEnumerator(_ option: EventRepeatingOption) -> EventRepeatTimeEnumerator {
        return EventRepeatTimeEnumerator(option)!
    }
    
    func dummyDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.date(from: dateString)!
    }
}


// MARK: - test every day

class EventRepeatTimeEnumeratorTests_everyDay: BaseEventRepeatTimeEnumeratorTests {
    
    private var dummyTimeAt: EventTime {
        return .at(.init(10, timeZone: "UTC"))
    }
    
    private var dummyTimeRange: EventTime {
        return .period(
            TimeStamp(10, timeZone: "UTC")..<TimeStamp(110, timeZone: "UTC")
        )
    }
}

extension EventRepeatTimeEnumeratorTests_everyDay {
    
    // 특정 시간 1일간격으로 반복 + 3일 간격으로 반복
    func testEnumerator_whenRepeatEventAtTimeEveryDay_getNextTimeUntilEnd() {
        // given
        var option = EventRepeatingOptions.EveryDay()
        var enumerator = self.makeEnumerator(option)
        
        // when + then
        // 1일 간격으로 반복시
        var next = enumerator.nextEventTime(from: self.dummyTimeAt, until: nil)
        XCTAssertEqual(next, .at(TimeStamp(10 + .days(1), timeZone: "UTC")))
        
        // 3일 간격으로 반복시
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        enumerator = self.makeEnumerator(option)
        next = enumerator.nextEventTime(from: self.dummyTimeAt, until: nil)
        XCTAssertEqual(next, .at(TimeStamp(10 + .days(3), timeZone: "UTC")))
        
        // 반복종료시간 초과시
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        enumerator = self.makeEnumerator(option)
        next = enumerator.nextEventTime(from: self.dummyTimeAt, until: .init(.days(2), timeZone: "UTC"))
        XCTAssertNil(next)
    }
    
    
    func testEnumerator_whenRepeatPeriodEveryDay_getNextTimeUntilEnd() {
        // given
        var option = EventRepeatingOptions.EveryDay()
        var enumerator = self.makeEnumerator(option)
        
        // when + then
        // 특정 기간 1일 간격으로 반복
        var next = enumerator.nextEventTime(from: self.dummyTimeRange, until: nil)
        XCTAssertEqual(next, self.dummyTimeRange.shift(.days(1)))
        
        // 특정기간 3일 간격으로 반복
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        enumerator = self.makeEnumerator(option)
        next = enumerator.nextEventTime(from: self.dummyTimeRange, until: nil)
        XCTAssertEqual(next, self.dummyTimeRange.shift(.days(3)))
        
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        enumerator = self.makeEnumerator(option)
        next = enumerator.nextEventTime(from: self.dummyTimeRange, until: .init(.days(2), timeZone: "UTC"))
        XCTAssertNil(next)
    }
}


// MARK: - test every week

class EventRepeatTimeEnumeratorTests_everyWeek: BaseEventRepeatTimeEnumeratorTests {
    
    private var dummyTimeAt: EventTime {
        let date = self.dummyDate("2023-04-11 07:00")
        return .at(.init(date.timeIntervalSince1970, timeZone: "KST"))
    }
    
    private var dummyTimeRange: EventTime {
        let start = self.dummyDate("2023-04-11 07:00")
        let end = self.dummyDate("2023-04-11 08:00")
        return .period(
            TimeStamp(start.timeIntervalSince1970, timeZone: "KST")
            ..<
            TimeStamp(end.timeIntervalSince1970, timeZone: "KST")
        )
    }
}

extension EventRepeatTimeEnumeratorTests_everyWeek {
    
    // 일주일뒤 다음일절 -> 화요일 특정 시간
    func testEnumerator_nextWeekAtTime() {
        // given
        func parameterizeTest(_ intervalWeek: Int, expected: String?, endTime: String? = nil) {
            // given
            let option = EventRepeatingOptions.EveryWeek(.init(abbreviation: "KST")!)
                |> \.interval .~ intervalWeek
                |> \.dayOfWeeks .~ [.tuesday]
            let enumerator = self.makeEnumerator(option)
            let endTime = endTime.map { TimeStamp(self.dummyDate($0).timeIntervalSince1970, timeZone: "KST") }
            
            // when
            let next = enumerator.nextEventTime(from: self.dummyTimeAt, until: endTime)
            
            // then
            if let expected = expected {
                let nextWeekEvent = self.dummyDate(expected)
                XCTAssertEqual(next, .at(.init(nextWeekEvent.timeIntervalSince1970, timeZone: "KST")))
            } else {
                XCTAssertNil(next)
            }
        }
        
        // when+then
        parameterizeTest(1, expected: "2023-04-18 07:00")
        parameterizeTest(2, expected: "2023-04-25 07:00")
        parameterizeTest(3, expected: "2023-05-02 07:00")
        parameterizeTest(3, expected: nil, endTime: "2023-05-01 20:00")
    }
    
    // 일주일뒤 다음일정 -> 화요일 12:00~13:00
    func testEnumerator_nextWeekAtPeriod() {
        // given
        func parameterizeTest(_ interval: Int, expected: (String, String)?, endTime: String? = nil) {
            // given
            let option = EventRepeatingOptions.EveryWeek(.init(abbreviation: "KST")!)
                |> \.interval .~ interval
                |> \.dayOfWeeks .~ [.tuesday]
            let enumerator = self.makeEnumerator(option)
            let endTIme = endTime.map { TimeStamp(self.dummyDate($0).timeIntervalSince1970, timeZone: "KST") }
            
            // when
            let next = enumerator.nextEventTime(from: self.dummyTimeRange, until: endTIme)
            
            // then
            if let expected {
                let nextWeekEvents = EventTime.period(
                    TimeStamp(self.dummyDate(expected.0).timeIntervalSince1970, timeZone: "KST")
                        ..<
                    TimeStamp(self.dummyDate(expected.1).timeIntervalSince1970, timeZone: "KST" )
                )
                XCTAssertEqual(next, nextWeekEvents)
            } else {
                XCTAssertNil(next)
            }
        }
        // when + then
        parameterizeTest(1, expected: ("2023-04-18 07:00", "2023-04-18 08:00"))
        parameterizeTest(2, expected: ("2023-04-25 07:00", "2023-04-25 08:00"))
        parameterizeTest(3, expected: ("2023-05-02 07:00", "2023-05-02 08:00"))
        parameterizeTest(3, expected: nil, endTime: "2023-05-01 07:00")
    }
    
    // 화, 금 반복할때 특정시간 + 현재는 화요일 -> 같은주 목요일
    func testEnumerator_whenRepeatAtTimeWithSomeWeekDays_nextDayIsSameWeek() {
        // given
        func parameterizeTest(_ interval: Int, expected: String?, endTime: String? = nil) {
            // given
            let option = EventRepeatingOptions.EveryWeek(.init(abbreviation: "KST")!)
                |> \.interval .~ interval
                |> \.dayOfWeeks .~ [.tuesday, .friday]
            let enumerator = self.makeEnumerator(option)
            let endTime = endTime.map { TimeStamp(self.dummyDate($0).timeIntervalSince1970, timeZone: "KST") }
            
            // when
            let next = enumerator.nextEventTime(from: self.dummyTimeAt, until: endTime)
            
            // then
            if let expected {
                let sameWeekEvent = self.dummyDate(expected)
                XCTAssertEqual(next, .at(.init(sameWeekEvent.timeIntervalSince1970, timeZone: "KST")))
            } else {
                XCTAssertNil(next)
            }
        }
        // when + then
        (1..<10).forEach {
            parameterizeTest($0, expected: "2023-04-14 07:00")
        }
        parameterizeTest(1, expected: nil, endTime: "2023-04-14 06:59")
    }

    // 화, 금 반복할때 12:00~13:00 + 현재는 화요일 -> 같은주 금요일
    func testEnumerator_whenRepeatPeriodWithSomeWeekDays_nextDayIsSameWeek() {
        // given
        func parameterizeTest(_ interval: Int, expected: (String, String)?, endTime: String? = nil) {
            // given
            let option = EventRepeatingOptions.EveryWeek(.init(abbreviation: "KST")!)
                |> \.interval .~ interval
                |> \.dayOfWeeks .~ [.tuesday, .friday]
            let enumerator = self.makeEnumerator(option)
            let endTime = endTime.map { TimeStamp(self.dummyDate($0).timeIntervalSince1970, timeZone: "KST") }
            
            // when
            let next = enumerator.nextEventTime(from: self.dummyTimeRange, until: endTime)
            
            // then
            if let expected {
                let sameWeekPeriod = EventTime.period(
                    TimeStamp(self.dummyDate(expected.0).timeIntervalSince1970, timeZone: "KST")
                    ..<
                    TimeStamp(self.dummyDate(expected.1).timeIntervalSince1970, timeZone: "KST")
                )
                XCTAssertEqual(next, sameWeekPeriod)
            } else {
                XCTAssertNil(next)
            }
        }
        
        // when + then
        (1..<10).forEach {
            parameterizeTest($0, expected: ("2023-04-14 07:00", "2023-04-14 08:00"))
        }
        parameterizeTest(1, expected: nil, endTime: "2023-04-14 07:59")
    }
}


// MARK: - test every month + with select weeks

class EventRepeatEnumeratorTests_everyMonthWithSelectWeeks: BaseEventRepeatTimeEnumeratorTests {
    
    private func parameterizeTestTimeAt(
        _ interval: Int,
        from: String,
        isOnlyWithSeekLast: Bool = false,
        expected: String?,
        endTime: String? = nil
    ) {
        // given
        let option = EventRepeatingOptions.EveryMonth(timeZone: TimeZone(abbreviation: "KST")!)
            |> \.interval .~ interval
            |> \.selection .~ .week(
                isOnlyWithSeekLast ? [.last] : [.seq(2), .seq(4), .last], [.tuesday, .thursday]
            )
        let enumerator = self.makeEnumerator(option)
        let endTime = endTime.map { TimeStamp(self.dummyDate($0).timeIntervalSince1970, timeZone: "KST") }
        
        // when
        let next = enumerator.nextEventTime(from: .at(
            TimeStamp(self.dummyDate(from).timeIntervalSince1970, timeZone: "KST")
        ), until: endTime)
        
        // then
        if let expected {
            let nextTime = TimeStamp(self.dummyDate(expected).timeIntervalSince1970, timeZone: "KST")
            XCTAssertEqual(next, .at(nextTime))
        } else {
            XCTAssertNil(next)
        }
    }
    
    // 같은 주차일때 다음 요일 검사
    func testEnumerator_timeAtNextEventTimeIsSameWeek() {
        // given
        
        // when + then
        (1..<10).forEach {
            parameterizeTestTimeAt($0, from: "2023-04-11 01:00", expected: "2023-04-13 01:00")
        }
        parameterizeTestTimeAt(1, from: "2023-04-11 01:00", expected: nil, endTime: "2023-04-13 00:00")
    }
    
    // 같은 주차 아니면 다음주차의 첫번째 요일 검사
    func testEnumerator_timeAtNextEventIsNotSameWeek() {
        // given
        
        // when + then
        (1..<10).forEach {
            parameterizeTestTimeAt($0, from: "2023-04-13 01:00", expected: "2023-04-25 01:00")
        }
        parameterizeTestTimeAt(1, from: "2023-04-13 01:00", expected: nil, endTime: "2023-04-25 00:00")
        parameterizeTestTimeAt(1, from: "2023-05-25 01:00", expected: "2023-05-30 01:00")
        parameterizeTestTimeAt(1, from: "2023-05-25 01:00", expected: nil, endTime: "2023-05-30 00:00")
    }
    
    // 다음주차가 다른달이면 다음달 첫번째 요일 검사
    func testEnumerator_timeAtNextEventIsNotSameMonth() {
        // given
        
        // when + then
        parameterizeTestTimeAt(1, from: "2023-04-27 01:00", expected: "2023-05-09 01:00")
        parameterizeTestTimeAt(2, from: "2023-04-27 01:00", expected: "2023-06-13 01:00")
        parameterizeTestTimeAt(1, from: "2023-05-30 01:00", expected: "2023-06-13 01:00")
        parameterizeTestTimeAt(1, from: "2023-04-27 01:00", isOnlyWithSeekLast: true, expected: "2023-05-30 01:00")
        parameterizeTestTimeAt(1, from: "2023-05-30 01:00", expected: nil, endTime: "2023-06-13 00:00")
    }
}


// MARK: - test every month + with select days

class EventRepeatEnumeratorTests_everyMonthWithSelectDays: BaseEventRepeatTimeEnumeratorTests {
    
    private func parameterizeTestTimeAt(
        _ interval: Int,
        from: String,
        expected: String?,
        endTime: String? = nil
    ) {
        // given
        let option = EventRepeatingOptions.EveryMonth(timeZone: TimeZone(abbreviation: "KST")!)
            |> \.interval .~ interval
            |> \.selection .~ .days([1, 15, 30, 31])
        let enumerator = self.makeEnumerator(option)
        let endTime = endTime.map { TimeStamp(self.dummyDate($0).timeIntervalSince1970, timeZone: "KST") }
        
        // when
        let next = enumerator.nextEventTime(from: .at(
            TimeStamp(self.dummyDate(from).timeIntervalSince1970, timeZone: "KST")
        ), until: endTime)
        
        // then
        if let expected {
            let nextTime = TimeStamp(self.dummyDate(expected).timeIntervalSince1970, timeZone: "KST")
            XCTAssertEqual(next, .at(nextTime))
        } else {
            XCTAssertNil(next)
        }
    }
    
    func testEnumerator_timeAtNextEventIsSameMonth_andNextDay() {
        // given
        // when + then
        parameterizeTestTimeAt(1, from: "2023-01-01 01:00", expected: "2023-01-15 01:00")
        parameterizeTestTimeAt(1, from: "2023-01-15 01:00", expected: "2023-01-30 01:00")
        parameterizeTestTimeAt(1, from: "2023-01-30 01:00", expected: "2023-01-31 01:00")
        parameterizeTestTimeAt(1, from: "2023-01-31 01:00", expected: nil, endTime: "2023-01-31 00:59")
    }
    
    func testEnumerator_timeAtNextEventIsNotSameMonth_andNextDay() {
        // given
        // when + then
        parameterizeTestTimeAt(1, from: "2023-01-31 01:00", expected: "2023-02-01 01:00")
        parameterizeTestTimeAt(1, from: "2023-02-01 01:00", expected: "2023-02-15 01:00")
        parameterizeTestTimeAt(1, from: "2023-02-15 01:00", expected: "2023-03-01 01:00")
        parameterizeTestTimeAt(1, from: "2023-02-15 01:00", expected: nil, endTime: "2023-02-28 00:59")
        parameterizeTestTimeAt(2, from: "2023-01-31 01:00", expected: "2023-03-01 01:00")
    }
}


// MARK: - test every year

class EventRepeatEnumeratorTests_everyYear: BaseEventRepeatTimeEnumeratorTests {
    
    private func parameterizeTests(
        _ interval: Int = 1,
        weekDays: [DayOfWeeks] = [.tuesday, .thursday],
        from: String,
        expected: String?,
        endTime: String? = nil
    ) {
        // given
        let option = EventRepeatingOptions.EveryYear(timeZone: TimeZone(abbreviation: "KST")!)
            |> \.interval .~ interval
            |> \.months .~ [.april, .august, .december]
            |> \.weekOrdinals .~ [ .seq(2), .seq(4), .last]
            |> \.dayOfWeek .~ weekDays
        let enumerator = self.makeEnumerator(option)
        let endTime = endTime.map { TimeStamp(self.dummyDate($0).timeIntervalSince1970, timeZone: "KST") }
        
        // when
        let next = enumerator.nextEventTime(from: .at(
            TimeStamp(self.dummyDate(from).timeIntervalSince1970, timeZone: "KST")
        ), until: endTime)
        
        // then
        if let expected {
            let nextTime = TimeStamp(self.dummyDate(expected).timeIntervalSince1970, timeZone: "KST")
            XCTAssertEqual(next, .at(nextTime))
        } else{
            XCTAssertNil(next)
        }
    }
    
    // 같은주에 다음일정 있으면 그거 리턴 + 같은 년도여야함
    func testEnumerator_nextEventTimeIsSameWeek() {
        // given
        // when + then
        self.parameterizeTests(from: "2023-04-11 01:00", expected: "2023-04-13 01:00")
        self.parameterizeTests(from: "2023-04-11 01:00", expected: nil, endTime: "2023-04-13 00:00")
    }
    
    // 다음주 첫 반복요일 + 같은 년도 + 같은 달
    func testEnumerator_nextEventTimeIsNextWeekFirstRepeatingDay() {
        // given
        // when + then
        self.parameterizeTests(from: "2023-04-13 01:00", expected: "2023-04-25 01:00")
        self.parameterizeTests(from: "2023-04-13 01:00", expected: nil, endTime: "2023-04-25 00:00")
    }
    
    // 다음달 첫 반복 주, 요일 + 같은 년도여야함
    func testEnumerator_nextEventTimeIsNextMonthFirstRepeatingWeekAndDay() {
        // given
        // when + then
        self.parameterizeTests(from: "2023-04-27 01:00", expected: "2023-08-08 01:00")
        self.parameterizeTests(from: "2023-04-27 01:00", expected: nil, endTime: "2023-08-08 00:00")
    }
    
    // 다음년도 첫 반복달,반복주, 요일 이여야함
    func testEnumerator_nextEventTimeIsNextYearFirstRepeatingMonthOrdinalAndWeekDay() {
        // given
        // when + then
        self.parameterizeTests(from: "2023-12-28 01:00", expected: "2024-04-09 01:00")
        self.parameterizeTests(from: "2023-12-28 01:00", expected: nil, endTime: "2023-04-09 00:00")
    }
}
