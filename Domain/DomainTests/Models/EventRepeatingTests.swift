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
            repeatingStartTime: .init(utcTimeInterval: 0),
            repeatOption: option
        )
        |> \.repeatingEndTime .~ endTime
    }
    
    func dummyDate(_ dateString: String, timeZone: String = "KST") -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(abbreviation: timeZone)
        return formatter.date(from: dateString)!
    }
}

class EventRepeatingTests_everyDay: BaseEventRepeatingTests {
    
    private var dummyTimeAt: EventTime {
        return .at(.init(utcTimeInterval: 10))
    }
    
    private var dummyTimeRange: EventTime {
        return .period(
            TimeStamp(utcTimeInterval: 10)..<TimeStamp(utcTimeInterval: 110)
        )
    }
    
    private var dummyTimeAllDays: EventTime {
        return .allDays(
            TimeStamp(utcTimeInterval: 100, withFixed: 1000)..<TimeStamp(utcTimeInterval: 72*3600+100, withFixed: 1000)
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
        XCTAssertEqual(next, .at(TimeStamp(utcTimeInterval: 10 + .days(1))))
        
        // 3일 간격으로 반복시
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        repeating = self.makeRepeating(option)
        next = repeating.nextEventTime(from: self.dummyTimeAt)
        XCTAssertEqual(next, .at(TimeStamp(utcTimeInterval: 10 + .days(3))))
        
        // 반복종료시간 초과시
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        repeating = self.makeRepeating(option, endTime: .init(utcTimeInterval: .days(2)))
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
        repeating = self.makeRepeating(option, endTime: .init(utcTimeInterval: .days(2)))
        next = repeating.nextEventTime(from: self.dummyTimeRange)
        XCTAssertNil(next)
    }
    
    func testRepeating_whenRepeatAllDays_getNextTimeUntilEnd() {
        // given
        var option = EventRepeatingOptions.EveryDay() |> \.interval .~ 7
        var repeating = self.makeRepeating(option)
        
        // when + then
        // 지정 3일 이벤트 -> 7일 간격으로 반복
        var next = repeating.nextEventTime(from: self.dummyTimeAllDays)
        XCTAssertEqual(next, self.dummyTimeAllDays.shift(.days(7)))
        
        // 지정 3일 이벤트 -> 7일 간격으로 반복시에 반복 종료시간 끝남
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 7
        repeating = self.makeRepeating(option, endTime: .init(utcTimeInterval: .days(10)))
        next = repeating.nextEventTime(from: self.dummyTimeAllDays)
        XCTAssertNil(next)
    }
}


// MARK: - test every week

class EventRepeatingTests_everyWeek: BaseEventRepeatingTests {
    
    private var dummyTimeAt: EventTime {
        let date = self.dummyDate("2023-04-11 20:00")
        return .at(.init(utcTimeInterval: date.timeIntervalSince1970))
    }
    
    private var dummyTimeRange: EventTime {
        let start = self.dummyDate("2023-04-11 07:00")
        let end = self.dummyDate("2023-04-11 08:00")
        return .period(
            TimeStamp(utcTimeInterval: start.timeIntervalSince1970)
            ..<
            TimeStamp(utcTimeInterval: end.timeIntervalSince1970)
        )
    }
    
    private var dummyAllDays: EventTime {
        let start = self.dummyDate("2023-04-11 00:00")
        let end = self.dummyDate("2023-04-12 00:00")
        return .allDays(
            TimeStamp(utcTimeInterval: start.timeIntervalSince1970, withFixed: .hours(9))
            ..<
            TimeStamp(utcTimeInterval: end.timeIntervalSince1970, withFixed: .hours(9))
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
                endTime: endTime.map { .init(utcTimeInterval: self.dummyDate($0).timeIntervalSince1970) }
            )
            
            // when
            let next = repeating.nextEventTime(from: self.dummyTimeAt)
            
            // then
            if let expected = expected {
                let nextWeekEvent = self.dummyDate(expected)
                XCTAssertEqual(next, .at(.init(utcTimeInterval: nextWeekEvent.timeIntervalSince1970)))
            } else {
                XCTAssertNil(next)
            }
        }
        
        // when+then
        parameterizeTest(1, expected: "2023-04-18 20:00")
        parameterizeTest(2, expected: "2023-04-25 20:00")
        parameterizeTest(3, expected: "2023-05-02 20:00")
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
                endTime: endTime.map { .init(utcTimeInterval: self.dummyDate($0).timeIntervalSince1970) }
            )
            
            // when
            let next = repeating.nextEventTime(from: self.dummyTimeRange)
            
            // then
            if let expected {
                let nextWeekEvents = EventTime.period(
                    TimeStamp(utcTimeInterval: self.dummyDate(expected.0).timeIntervalSince1970)
                        ..<
                    TimeStamp(utcTimeInterval: self.dummyDate(expected.1).timeIntervalSince1970)
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
    
    // 일주일뒤 다음일정 -> 하루종일 화요일부터 - 수요일
    func testRepeating_nextWeekAtAllDays() {
        // given
        func parameterizeTests(_ interval: Int, expected: (String, String)?, endTime: String? = nil) {
            // given
            let option = EventRepeatingOptions.EveryWeek(.init(abbreviation: "KST")!)
                |> \.interval .~ interval
                |> \.dayOfWeeks .~ [.tuesday]
            let repeating = self.makeRepeating(
                option,
                endTime: endTime.map { .init(utcTimeInterval: self.dummyDate($0).timeIntervalSince1970) }
            )
            
            // when
            let next = repeating.nextEventTime(from: self.dummyAllDays)
            
            // then
            if let expected {
                let nextWeekEvents = EventTime.allDays(
                    TimeStamp(utcTimeInterval: self.dummyDate(expected.0).timeIntervalSince1970, withFixed: .hours(9))
                        ..<
                    TimeStamp(utcTimeInterval: self.dummyDate(expected.1).timeIntervalSince1970, withFixed: .hours(9))
                )
                XCTAssertEqual(next, nextWeekEvents)
            } else {
                XCTAssertNil(next)
            }
        }
        
        // when + then
        parameterizeTests(1, expected: ("2023-04-18 00:00", "2023-04-19 00:00"))
        parameterizeTests(2, expected: ("2023-04-25 00:00", "2023-04-26 00:00"))
        parameterizeTests(3, expected: ("2023-05-02 00:00", "2023-05-03 00:00"))
    }
    
    // 화, 목 반복할때 특정시간 + 현재는 화요일 -> 같은주 목요일
    // 화, 목 반복할때 12:00~13:00 + 현재는 화요일 -> 같은주 목요일
    // 화, 목 반복할때 화요일-수요일 + 현재는 화요일 -> 같은주 목요일-금요일
}
