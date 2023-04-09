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


class EventRepeatingTests: BaseTestCase {
    
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
    
    private func makeRepeating(
        _ option: EventRepeatingOption,
        endTime: TimeStamp? = nil
    ) -> EventRepeating {
        return EventRepeating(
            repeatingStartTime: .init(utcTimeInterval: 0),
            repeatOption: option
        )
        |> \.repeatingEndTime .~ endTime
    }
}

// MARK: - test every day

extension EventRepeatingTests {
    
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
        repeating = self.makeRepeating(option, endTime: .init(utcTimeInterval: .days(10) + 100))
        next = repeating.nextEventTime(from: self.dummyTimeAllDays)
        XCTAssertNil(next)
        
        // 지정 3일 이벤트 -> 7일 간격으로 반복시에 utc offset 포함 반복 종료시간 안끝남
        option = EventRepeatingOptions.EveryDay() |> \.interval .~ 7
        repeating = self.makeRepeating(option, endTime: .init(utcTimeInterval: .days(10)+100+1000))
        next = repeating.nextEventTime(from: self.dummyTimeAllDays)
        XCTAssertEqual(next, self.dummyTimeAllDays.shift(.days(7)))
    }
}
