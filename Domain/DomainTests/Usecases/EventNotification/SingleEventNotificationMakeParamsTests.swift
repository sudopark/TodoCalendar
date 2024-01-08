//
//  SingleEventNotificationMakeParamsTests.swift
//  Domain
//
//  Created by sudo.park on 1/8/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Prelude
import Optics
@testable import Domain


class SingleEventNotificationMakeParamsTests: XCTestCase { }


// MARK: - test params from event

extension SingleEventNotificationMakeParamsTests {
    
    private var dummyFutureTime: TimeInterval {
        return Date().addingTimeInterval(100).timeIntervalSince1970
    }
    
    private var kstTimeZone: TimeZone {
        return TimeZone(abbreviation: "KST")!
    }
    
    func testParams_makeFromTodoEvent() {
        // given
        let event = TodoEvent(uuid: "id", name: "name")
            |> \.time .~ .at(self.dummyFutureTime)
        
        // when
        let params = SingleEventNotificationMakeParams(
            todo: event, in: self.kstTimeZone, timeOption: .atTime
        )
        
        // then
        XCTAssertEqual(params?.eventType, .todo)
        XCTAssertEqual(params?.eventId, "id")
        XCTAssertEqual(params?.eventName, "(\("Todo".localized()))name")
    }
    
    func testParams_makeFromScheduleEvent() {
        // given
        let event = ScheduleEvent(
            uuid: "id", name: "name", time: .at(self.dummyFutureTime)
        )
        
        // when
        let params = SingleEventNotificationMakeParams(
            schedule: event, repeatingAt: nil, in: self.kstTimeZone, with: .atTime
        )
        
        // then
        XCTAssertEqual(params?.eventType, .schedule)
        XCTAssertEqual(params?.eventId, "id")
        XCTAssertEqual(params?.eventName, "name")
    }
}


// MARK: - test params time text and notification schedule components

// at 이벤트 시간 => 알림 옵션에 따라 timeText 변환
extension SingleEventNotificationMakeParamsTests {
    
    private var dummyEvent: TodoEvent {
        return TodoEvent(uuid: "uid", name: "name")
    }
    
    private var dummyTime: Date {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.kstTimeZone
        return calendar.dateBySetting(from: Date()) {
            $0.hour = 23; $0.minute = 59; $0.second = 59
        }!
    }
    
    func testParams_timeTextFromTimeAndOptions() {
        // given
        let refTime = self.dummyTime
        let refTimeNextWeek = refTime.add(days: 7)!
        
        func parameterizeTest(
            _ time: Date,
            _ option: EventNotificationTimeOption,
            expectTiext: String?,
            expectComponent: DateComponents?
        ) {
            // given
            let event = self.dummyEvent |> \.time .~ .at(
                time.timeIntervalSince1970
            )
            
            // when
            let params = SingleEventNotificationMakeParams(
                todo: event,
                in: self.kstTimeZone,
                timeOption: option
            )
            
            // then
            let text = params?.eventTimeText
            let components = params?.scheduleDateComponents
            XCTAssertEqual(text, expectTiext)
            XCTAssertEqual(components, expectComponent)
        }
        
        // when + then
        // 해당 시간
        parameterizeTest(
            refTime,
            .atTime,
            expectTiext: refTime.asText(prefix: "Today".localized(), "HH:mm".localized()),
            expectComponent: refTime.components(kstTimeZone)
        )
        // 1분 전
        parameterizeTest(
            refTime,
            .before(seconds: 60),
            expectTiext: refTime.asText(prefix: "Today".localized(), "HH:mm".localized()),
            expectComponent: refTime.addingTimeInterval(-60).components(kstTimeZone)
        )
        // 5분 전
        parameterizeTest(
            refTime,
            .before(seconds: 300),
            expectTiext: refTime.asText(prefix: "Today".localized(), "HH:mm".localized()),
            expectComponent: refTime.addingTimeInterval(-300).components(kstTimeZone)
        )
        // 10분전
        parameterizeTest(
            refTime,
            .before(seconds: 600),
            expectTiext: refTime.asText(prefix: "Today".localized(), "HH:mm".localized()),
            expectComponent: refTime.addingTimeInterval(-600).components(kstTimeZone)
        )
        // 15분전
        parameterizeTest(
            refTime,
            .before(seconds: 60*15),
            expectTiext: refTime.asText(prefix: "Today".localized(), "HH:mm".localized()),
            expectComponent: refTime.addingTimeInterval(-60*15).components(kstTimeZone)
        )
        // 30분전
        parameterizeTest(
            refTime,
            .before(seconds: 60*30),
            expectTiext: refTime.asText(prefix: "Today".localized(), "HH:mm".localized()),
            expectComponent: refTime.addingTimeInterval(-60*30).components(kstTimeZone)
        )
        // 1시간전
        parameterizeTest(
            refTime,
            .before(seconds: 3600),
            expectTiext: refTime.asText(prefix: "Today".localized(), "HH:mm".localized()),
            expectComponent: refTime.addingTimeInterval(-3600).components(kstTimeZone)
        )
        // 2시간전
        parameterizeTest(
            refTime,
            .before(seconds: 3600*2),
            expectTiext: refTime.asText(prefix: "Today".localized(), "HH:mm".localized()),
            expectComponent: refTime.addingTimeInterval(-3600*2).components(kstTimeZone)
        )
        // 1일전
        parameterizeTest(
            refTimeNextWeek,
            .before(seconds: 3600*24),
            expectTiext: refTimeNextWeek.asText("MM d, HH:mm".localized()),
            expectComponent: refTimeNextWeek.addingTimeInterval(-3600*24).components(kstTimeZone)
        )
        // 2일전
        parameterizeTest(
            refTimeNextWeek,
            .before(seconds: 3600*24*2),
            expectTiext: refTimeNextWeek.asText("MM d, HH:mm".localized()),
            expectComponent: refTimeNextWeek.addingTimeInterval(-3600*24*2).components(kstTimeZone)
        )
        // 1주일전
        parameterizeTest(
            refTimeNextWeek,
            .before(seconds: 3600*24*7),
            expectTiext: refTimeNextWeek.asText("MM d, HH:mm".localized()),
            expectComponent: refTimeNextWeek.addingTimeInterval(-3600*24*7).components(kstTimeZone)
        )
        
        // 하루종일 - 당일
        parameterizeTest(refTime, .allDay9AM, expectTiext: nil, expectComponent: nil)
    }
    
    private var dummyAllDayPeriod: Range<Date> {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.kstTimeZone
        let date = self.dummyTime.add(days: 14)!
        let start = calendar.startOfDay(for: date)
        let end = calendar.endOfDay(for: date)!
        return start..<end
    }

    func testParams_timeTextFromAllDayEventTimeAndOptions() {
        // given
        let range = self.dummyAllDayPeriod
        
        func parameterizeTest(
            option: EventNotificationTimeOption,
            _ expectText: String?,
            _ expectComponents: DateComponents?
        ) {
            // given
            let event = self.dummyEvent |> \.time .~ .allDay(
                range.lowerBound.timeIntervalSince1970..<range.upperBound.timeIntervalSince1970,
                secondsFromGMT: kstTimeZone.secondsFromGMT() |> TimeInterval.init
            )
            
            // when
            let params = SingleEventNotificationMakeParams(
                todo: event,
                in: kstTimeZone,
                timeOption: option
            )
            
            // then
            let text = params?.eventTimeText
            let components = params?.scheduleDateComponents
            XCTAssertEqual(text, expectText)
            XCTAssertEqual(components, expectComponents)
        }
        
        // when + then
        let day = range.lowerBound
        parameterizeTest(
            option: .allDay9AM,
            day.at9A(kstTimeZone).allDayText(),
            day.at9A(kstTimeZone).components(kstTimeZone)
        )
        let before1Day = day.add(days: -1)!
        parameterizeTest(
            option: .allDay9AMBefore(seconds: 3600*24),
            day.at9A(kstTimeZone).allDayText(),
            before1Day.at9A(kstTimeZone).components(kstTimeZone)
        )
        let before1week = day.add(days: -7)!
        parameterizeTest(
            option: .allDay9AMBefore(seconds: 3600*24*7),
            day.at9A(kstTimeZone).allDayText(),
            before1week.at9A(kstTimeZone).components(kstTimeZone)
        )
        parameterizeTest(option: .atTime, nil, nil)
    }
}

private extension Date {
    
    func asText(prefix: String? = nil, _ form: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = form
        let formedText = formatter.string(from: self)
        return prefix.map { "\($0) \(formedText)"} ?? formedText
    }
    
    func allDayText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM d".localized()
        return "\(formatter.string(from: self)) \("all day".localized())"
    }
    
    func components(_ timeZone: TimeZone) -> DateComponents {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        return calendar.dateComponents([
            .year, .month, .day, .hour, .minute, .second
        ], from: self)
        |> \.calendar .~ Calendar(identifier: .gregorian)
        |> \.timeZone .~ pure(timeZone)
    }
    
    func at9A(_ timeZone: TimeZone) -> Date {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        return calendar.dateBySetting(from: self) {
            $0.hour = 9; $0.minute = 0; $0.second = 0
        }!
    }
}
