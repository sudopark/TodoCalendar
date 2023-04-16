//
//  EventRepeatingTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/04/09.
//

import XCTest
import Prelude
import Optics
import UnitTestHelpKit

@testable import Domain


class BaseEventRepeatingTests: BaseTestCase {
 
    func makeRepeating(
        _ option: EventRepeatingOption,
        endTime: TimeStamp? = nil
    ) -> EventRepeating {
        return EventRepeating(
            repeatingStartTime: .init(0, timeZone: "UTC"),
            repeatOption: option
        )
        |> \.repeatingEndTime .~ endTime
    }
    
    func dummyDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.date(from: dateString)!
    }
}

class EventRepeatingTests_everyDay: BaseEventRepeatingTests {
    
    private var dummyTimeAt: EventTime {
        return .at(.init(10, timeZone: "UTC"))
    }
    
    private var dummyTimeRange: EventTime {
        return .period(
            TimeStamp(10, timeZone: "UTC")..<TimeStamp(110, timeZone: "UTC")
        )
    }
}

// MARK: - test every day

extension EventRepeatingTests_everyDay {
    
    // 특정 시간 1일간격으로 반복 + 3일 간격으로 반복
    func testRepeating_whenRepeatEventAtTimeEveryDay_getNextTimeUntilEnd() {
        // given
        var option = EventRepeatingOptions.EveryDay()
        var repeating = self.makeRepeating(option)
        
        // when + then
        // 1일 간격으로 반복시
        var next = repeating.nextEventTime(from: self.dummyTimeAt)
        XCTAssertEqual(next, .at(TimeStamp(10 + .days(1), timeZone: "UTC")))
        
        // 3일 간격으로 반복시
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        repeating = self.makeRepeating(option)
        next = repeating.nextEventTime(from: self.dummyTimeAt)
        XCTAssertEqual(next, .at(TimeStamp(10 + .days(3), timeZone: "UTC")))
        
        // 반복종료시간 초과시
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        repeating = self.makeRepeating(option, endTime: .init(.days(2), timeZone: "UTC"))
        next = repeating.nextEventTime(from: self.dummyTimeAt)
        XCTAssertNil(next)
    }
    
    
    func testRepeating_whenRepeatPeriodEveryDay_getNextTimeUntilEnd() {
        // given
        var option = EventRepeatingOptions.EveryDay()
        var repeating = self.makeRepeating(option)
        
        // when + then
        // 특정 기간 1일 간격으로 반복
        var next = repeating.nextEventTime(from: self.dummyTimeRange)
        XCTAssertEqual(next, self.dummyTimeRange.shift(.days(1)))
        
        // 특정기간 3일 간격으로 반복
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        repeating = self.makeRepeating(option)
        next = repeating.nextEventTime(from: self.dummyTimeRange)
        XCTAssertEqual(next, self.dummyTimeRange.shift(.days(3)))
        
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        repeating = self.makeRepeating(option, endTime: .init(.days(2), timeZone: "UTC"))
        next = repeating.nextEventTime(from: self.dummyTimeRange)
        XCTAssertNil(next)
    }
}


// MARK: - test every week

class EventRepeatingTests_everyWeek: BaseEventRepeatingTests {
    
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
    
    // 일주일뒤 다음일절 -> 화요일 특정 시간
    func testRepeating_nextWeekAtTime() {
        // given
        func parameterizeTest(_ intervalWeek: Int, expected: String?, endTime: String? = nil) {
            // given
            let option = EventRepeatingOptions.EveryWeek(.init(abbreviation: "KST")!)
                |> \.interval .~ intervalWeek
                |> \.dayOfWeeks .~ [.tuesday]
            let repeating = self.makeRepeating(
                option,
                endTime: endTime.map { .init(self.dummyDate($0).timeIntervalSince1970, timeZone: "KST") }
            )
            
            // when
            let next = repeating.nextEventTime(from: self.dummyTimeAt)
            
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
    func testRepeating_nextWeekAtPeriod() {
        // given
        func parameterizeTest(_ interval: Int, expected: (String, String)?, endTime: String? = nil) {
            // given
            let option = EventRepeatingOptions.EveryWeek(.init(abbreviation: "KST")!)
                |> \.interval .~ interval
                |> \.dayOfWeeks .~ [.tuesday]
            let repeating = self.makeRepeating(
                option,
                endTime: endTime.map { .init(self.dummyDate($0).timeIntervalSince1970, timeZone: "KST") }
            )
            
            // when
            let next = repeating.nextEventTime(from: self.dummyTimeRange)
            
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
    func testRepeating_whenRepeatAtTimeWithSomeWeekDays_nextDayIsSameWeek() {
        // given
        func parameterizeTest(_ interval: Int, expected: String?, endTime: String? = nil) {
            // given
            let option = EventRepeatingOptions.EveryWeek(.init(abbreviation: "KST")!)
                |> \.interval .~ interval
                |> \.dayOfWeeks .~ [.tuesday, .friday]
            let repeating = self.makeRepeating(
                option,
                endTime: endTime.map { .init(self.dummyDate($0).timeIntervalSince1970, timeZone: "KST") }
            )
            
            // when
            let next = repeating.nextEventTime(from: self.dummyTimeAt)
            
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
    func testRepeating_whenRepeatPeriodWithSomeWeekDays_nextDayIsSameWeek() {
        // given
        func parameterizeTest(_ interval: Int, expected: (String, String)?, endTime: String? = nil) {
            // given
            let option = EventRepeatingOptions.EveryWeek(.init(abbreviation: "KST")!)
                |> \.interval .~ interval
                |> \.dayOfWeeks .~ [.tuesday, .friday]
            let repeating = self.makeRepeating(
                option,
                endTime: endTime.map { .init(self.dummyDate($0).timeIntervalSince1970, timeZone: "KST") }
            )
            
            // when
            let next = repeating.nextEventTime(from: self.dummyTimeRange)
            
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
