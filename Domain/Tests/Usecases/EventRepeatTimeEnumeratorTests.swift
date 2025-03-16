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
    
    func makeEnumerator(
        _ option: any EventRepeatingOption,
        endOption: EventRepeating.RepeatEndOption? = nil,
        without: Set<String> = []
    ) -> EventRepeatTimeEnumerator {
        return EventRepeatTimeEnumerator(
            option, endOption: endOption, without: without
        )!
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
    
    private var dummyTimeAt: RepeatingTimes {
        return .init(time: .at(10), turn: 0)
    }
    
    private var dummyTimeRange: RepeatingTimes {
        return .init(time: .period(10..<110), turn: 0)
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
        var next = enumerator.nextEventTime(
            from: self.dummyTimeAt, until: nil
        )
        XCTAssertEqual(next?.time, .at(10 + .days(1)))
        XCTAssertEqual(next?.turn, 1)
        
        // 3일 간격으로 반복시
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        enumerator = self.makeEnumerator(option)
        next = enumerator.nextEventTime(from: self.dummyTimeAt, until: nil)
        XCTAssertEqual(next?.time, .at(10 + .days(3)))
        XCTAssertEqual(next?.turn, 1)
        
        // 반복 종료 시간과 동일한 경우
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        enumerator = self.makeEnumerator(option)
        next = enumerator.nextEventTime(from: self.dummyTimeAt, until: .days(3) + 10)
        XCTAssertEqual(next?.time, .at(10 + .days(3)))
        XCTAssertEqual(next?.turn, 1)
        
        // 반복종료시간 초과시
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        enumerator = self.makeEnumerator(option)
        next = enumerator.nextEventTime(from: self.dummyTimeAt, until: .days(2))
        XCTAssertNil(next)
    }
    
    
    func testEnumerator_whenRepeatPeriodEveryDay_getNextTimeUntilEnd() {
        // given
        var option = EventRepeatingOptions.EveryDay()
        var enumerator = self.makeEnumerator(option)
        
        // when + then
        // 특정 기간 1일 간격으로 반복
        var next = enumerator.nextEventTime(from: self.dummyTimeRange, until: nil)
        XCTAssertEqual(next?.time, self.dummyTimeRange.time.shift(.days(1)))
        XCTAssertEqual(next?.turn, 1)
        
        // 특정기간 3일 간격으로 반복
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        enumerator = self.makeEnumerator(option)
        next = enumerator.nextEventTime(from: self.dummyTimeRange, until: nil)
        XCTAssertEqual(next?.time, self.dummyTimeRange.time.shift(.days(3)))
        XCTAssertEqual(next?.turn, 1)
        
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        enumerator = self.makeEnumerator(option)
        next = enumerator.nextEventTime(from: self.dummyTimeRange, until: .days(2))
        XCTAssertNil(next)
    }
}


// MARK: - test every week

class EventRepeatTimeEnumeratorTests_everyWeek: BaseEventRepeatTimeEnumeratorTests {
    
    private var dummyTimeAt: RepeatingTimes {
        let date = self.dummyDate("2023-04-11 07:00")
        return .init(time: .at(date.timeIntervalSince1970), turn: 0)
    }
    
    private var dummyTimeRange: RepeatingTimes {
        let start = self.dummyDate("2023-04-11 07:00")
        let end = self.dummyDate("2023-04-11 08:00")
        return .init(
            time: .period(
                start.timeIntervalSince1970..<end.timeIntervalSince1970
            ),
            turn: 0
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
            let endTime = endTime.map { self.dummyDate($0).timeIntervalSince1970 }
            
            // when
            let next = enumerator.nextEventTime(from: self.dummyTimeAt, until: endTime)
            
            // then
            if let expected = expected {
                let nextWeekEvent = self.dummyDate(expected)
                XCTAssertEqual(next?.time, .at(nextWeekEvent.timeIntervalSince1970))
                XCTAssertEqual(next?.turn, 1)
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
            let endTIme = endTime.map { self.dummyDate($0).timeIntervalSince1970 }
            
            // when
            let next = enumerator.nextEventTime(from: self.dummyTimeRange, until: endTIme)
            
            // then
            if let expected {
                let nextWeekEvents = EventTime.period(
                    self.dummyDate(expected.0).timeIntervalSince1970
                        ..<
                    self.dummyDate(expected.1).timeIntervalSince1970
                )
                XCTAssertEqual(next?.time, nextWeekEvents)
                XCTAssertEqual(next?.turn, 1)
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
            let endTime = endTime.map { self.dummyDate($0).timeIntervalSince1970 }
            
            // when
            let next = enumerator.nextEventTime(from: self.dummyTimeAt, until: endTime)
            
            // then
            if let expected {
                let sameWeekEvent = self.dummyDate(expected)
                XCTAssertEqual(next?.time, .at(sameWeekEvent.timeIntervalSince1970))
                XCTAssertEqual(next?.turn, 1)
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
            let endTime = endTime.map { self.dummyDate($0).timeIntervalSince1970 }
            
            // when
            let next = enumerator.nextEventTime(from: self.dummyTimeRange, until: endTime)
            
            // then
            if let expected {
                let sameWeekPeriod = EventTime.period(
                    self.dummyDate(expected.0).timeIntervalSince1970
                    ..<
                    self.dummyDate(expected.1).timeIntervalSince1970
                )
                XCTAssertEqual(next?.time, sameWeekPeriod)
                XCTAssertEqual(next?.turn, 1)
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
        let endTime = endTime.map { self.dummyDate($0).timeIntervalSince1970 }
        
        // when
        let start = RepeatingTimes(
            time: .at(self.dummyDate(from).timeIntervalSince1970),
            turn: 0
        )
        let next = enumerator.nextEventTime(from: start, until: endTime)
        
        // then
        if let expected {
            let nextTime = self.dummyDate(expected).timeIntervalSince1970
            XCTAssertEqual(next?.time, .at(nextTime))
            XCTAssertEqual(next?.turn, 1)
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
        let endTime = endTime.map { self.dummyDate($0).timeIntervalSince1970 }
        
        // when
        let start = RepeatingTimes(
            time: .at(self.dummyDate(from).timeIntervalSince1970),
            turn: 0
        )
        let next = enumerator.nextEventTime(from: start, until: endTime)
        
        // then
        if let expected {
            let nextTime = self.dummyDate(expected).timeIntervalSince1970
            XCTAssertEqual(next?.time, .at(nextTime))
            XCTAssertEqual(next?.turn, 1)
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
        let endTime = endTime.map { self.dummyDate($0).timeIntervalSince1970 }
        
        // when
        let start = RepeatingTimes(
            time: .at(self.dummyDate(from).timeIntervalSince1970), turn: 0
        )
        let next = enumerator.nextEventTime(from: start, until: endTime)
        
        // then
        if let expected {
            let nextTime = self.dummyDate(expected).timeIntervalSince1970
            XCTAssertEqual(next?.time, .at(nextTime))
            XCTAssertEqual(next?.turn, 1)
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

// MARK: - repeat every year some day

class EventRepeatEnumeratorTests_everyYear_someDay: BaseEventRepeatTimeEnumeratorTests {
 
    private func parameterizeTest(
        interval: Int = 1,
        from: String,
        _ fromMonth: Int, _ fromDay: Int,
        expected: String?,
        endTime: String? = nil
    ) {
        // given
        
        let option = EventRepeatingOptions.EveryYearSomeDay(
            TimeZone(abbreviation: "KST")!, fromMonth, fromDay
        )
        |> \.interval .~ interval
        let enumerator = self.makeEnumerator(option)
        let endTime = endTime.map { self.dummyDate($0).timeIntervalSince1970 }
        
        // when
        let start = RepeatingTimes(
            time: .at(self.dummyDate(from).timeIntervalSince1970), turn: 0
        )
        let next = enumerator.nextEventTime(from: start, until: endTime)
        
        // then
        if let expected {
            let expectedNextTime = self.dummyDate(expected).timeIntervalSince1970
            XCTAssertEqual(next?.time, .at(expectedNextTime))
            XCTAssertEqual(next?.turn, 1)
        } else {
            XCTAssertNil(next)
        }
    }
    
    // interval에 따라 다음년도 같은시간 반환
    func testEnumerator_nextTimePerInterval() {
        // given
        // when + then
        self.parameterizeTest(
            interval: 1, from: "2023-03-01 01:00", 3, 1,
            expected: "2024-03-01 01:00"
        )
        self.parameterizeTest(
            interval: 2, from: "2023-03-01 01:00", 3, 1,
            expected: "2025-03-01 01:00"
        )
        self.parameterizeTest(
            interval: 1, from: "2020-02-29 01:00", 2, 29,
            expected: "2021-02-28 01:00"
        )
        self.parameterizeTest(
            interval: 2, from: "2020-02-29 01:00", 2, 29,
            expected: "2022-02-28 01:00"
        )
        self.parameterizeTest(
            interval: 3, from: "2020-02-29 01:00", 2, 29,
            expected: "2023-02-28 01:00"
        )
        self.parameterizeTest(
            interval: 4, from: "2020-02-29 01:00", 2, 29,
            expected: "2024-02-29 01:00"
        )
    }
}

// MARK: - enumerate until end

class EventRepeatEnumeratorTests_EnumeratesUntilEnd: BaseEventRepeatTimeEnumeratorTests {
    
    func testEnumerator_enumerateUntilEnd() {
        // given
        let option = EventRepeatingOptions.EveryDay()
            |> \.interval .~ 3
        let enumerator = self.makeEnumerator(option)
        let startTimeStamp = RepeatingTimes(
            time: .at(self.dummyDate("2023-05-20 01:00").timeIntervalSince1970),
            turn: 0
        )
        let endTime = self.dummyDate("2023-06-01 01:00").timeIntervalSince1970
        
        // when
        let eventTimes = enumerator.nextEventTimes(from: startTimeStamp, until: endTime)
        
        // then
        XCTAssertEqual(eventTimes.map { $0.time }, [
            .at(self.dummyDate("2023-05-23 01:00").timeIntervalSince1970),
            .at(self.dummyDate("2023-05-26 01:00").timeIntervalSince1970),
            .at(self.dummyDate("2023-05-29 01:00").timeIntervalSince1970),
            .at(self.dummyDate("2023-06-01 01:00").timeIntervalSince1970),
        ])
        XCTAssertEqual(eventTimes.map { $0.turn }, [
            1, 2, 3, 4
        ])
    }
}


// MARK: - enumerate end by count

final class EventRepeatEnumeratorTests_EnmeratesEndByCount: BaseEventRepeatTimeEnumeratorTests {
    
    func testEnumerator_enumerateByCount() {
        // given
        let option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        let enumerator = self.makeEnumerator(option, endOption: .count(3))
        let startTimeStamp = RepeatingTimes(
            time: .at(self.dummyDate("2023-05-20 01:00").timeIntervalSince1970),
            turn: 0
        )
        let endTime = self.dummyDate("2024-06-01 01:00").timeIntervalSince1970
        
        // when
        let eventTimes = enumerator.nextEventTimes(from: startTimeStamp, until: endTime)
        
        // then
        XCTAssertEqual(eventTimes.map { $0.time }, [
            .at(self.dummyDate("2023-05-23 01:00").timeIntervalSince1970),
            .at(self.dummyDate("2023-05-26 01:00").timeIntervalSince1970),
        ])
        XCTAssertEqual(eventTimes.map { $0.turn }, [
            1, 2
        ])
    }
    
    func testEnumerator_whenExcludeDateExists_excludeCount() {
        // given
        let option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        let excludes = ["2023-05-26 01:00", "2023-06-01 01:00"]
            .map { self.dummyDate($0).timeIntervalSince1970 }
            .map { EventTime.at($0) }
            .map { $0.customKey }
        let enumerator = self.makeEnumerator(
            option, endOption: .count(4), without: Set(excludes)
        )
        let startTimeStamp = RepeatingTimes(
            time: .at(self.dummyDate("2023-05-20 01:00").timeIntervalSince1970),
            turn: 0
        )
        let endTime = self.dummyDate("2024-06-01 01:00").timeIntervalSince1970
        
        // when
        let eventTimes = enumerator.nextEventTimes(from: startTimeStamp, until: endTime)
        
        // then
        XCTAssertEqual(eventTimes.map { $0.time }, [
            .at(self.dummyDate("2023-05-23 01:00").timeIntervalSince1970),
            .at(self.dummyDate("2023-05-29 01:00").timeIntervalSince1970),
            .at(self.dummyDate("2023-06-04 01:00").timeIntervalSince1970),
        ])
        XCTAssertEqual(eventTimes.map { $0.turn }, [
            1, 2, 3
        ])
    }
}
