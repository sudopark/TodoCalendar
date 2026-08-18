//
//  RRuleParserTests.swift
//  DomainTests
//
//  Created by sudo.park on 5/25/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Extensions
import UnitTestHelpKit

@testable import Domain

struct RRuleParserTests {
    
    @Test func parse_everyDay() {
        // given
        let text = "RRULE:FREQ=DAILY;INTERVAL=5"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .DAILY)
        #expect(rrule?.interval == 5)
        #expect(rrule?.byDays == [])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_everyWeek() {
        // given
        let text = "RRULE:FREQ=WEEKLY;BYDAY=TU"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .WEEKLY)
        #expect(rrule?.interval == 1)
        #expect(rrule?.byDays == [.init(weekDay: .TU)])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_everyMonthNthWeekDay() {
        // given
        let text = "RRULE:FREQ=MONTHLY;BYDAY=-1WE"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .MONTHLY)
        #expect(rrule?.interval == 1)
        #expect(rrule?.byDays == [.init(ordinal: -1, weekDay: .WE)])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_everyMonthSomeDay() {
        // given
        let text = "RRULE:FREQ=MONTHLY;INTERVAL=2"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .MONTHLY)
        #expect(rrule?.interval == 2)
        #expect(rrule?.byDays == [])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_everyYear() {
        // given
        let text = "RRULE:FREQ=YEARLY"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .YEARLY)
        #expect(rrule?.interval == 1)
        #expect(rrule?.byDays == [])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_everyWorkDay() {
        // given
        let text = "RRULE:FREQ=WEEKLY;BYDAY=FR,MO,TH,TU,WE"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .WEEKLY)
        #expect(rrule?.interval == 1)
        #expect(rrule?.byDays == [
            .init(weekDay: .FR), .init(weekDay: .MO), .init(weekDay: .TH),
            .init(weekDay: .TU), .init(weekDay: .WE)
        ])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_endTime() {
        // given
        let text = "RRULE:FREQ=WEEKLY;WKST=MO;UNTIL=20250816T145959Z;BYDAY=SA"
        
        // when
        let rrule = RRuleParser.parse(text)
        
        // then
        #expect(rrule?.freq == .WEEKLY)
        #expect(rrule?.interval == 1)
        #expect(rrule?.byDays == [.init(weekDay: .SA)])
        #expect(rrule?.until != nil)
        let endtimeText = rrule?.until.flatMap {
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            return formatter.string(from: $0)
        }
        #expect(endtimeText == "2025-08-16T14:59:59Z")
        #expect(rrule?.count == nil)
    }
    
    @Test func parse_endCount() {
        // given
        let text = "RRULE:FREQ=DAILY;COUNT=3"

        // when
        let rrule = RRuleParser.parse(text)

        // then
        #expect(rrule?.freq == .DAILY)
        #expect(rrule?.interval == 1)
        #expect(rrule?.byDays == [])
        #expect(rrule?.until == nil)
        #expect(rrule?.count == 3)
    }
}

// MARK: - 월·일 지정 키 파싱

extension RRuleParserTests {

    @Test func parse_byMonthDayAndByMonth() {
        // given
        let text = "RRULE:FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15"

        // when
        let rrule = RRuleParser.parse(text)

        // then
        #expect(rrule?.byMonths == [3])
        #expect(rrule?.byMonthDays == [15])
        #expect(rrule?.unsupportedKeys.isEmpty == true)
    }
}

// MARK: - 미지원 키 수집

extension RRuleParserTests {

    @Test func parse_collectsUnsupportedKeys() {
        // given
        let text = "RRULE:FREQ=MONTHLY;BYSETPOS=-1;BYDAY=MO;WKST=SU"

        // when
        let rrule = RRuleParser.parse(text)

        // then
        let unsupportedKeys = Set(rrule?.unsupportedKeys ?? [])
        #expect(unsupportedKeys == Set(["BYSETPOS", "WKST"]))
    }

    @Test func parse_knownKeysLeaveUnsupportedEmpty() {
        // given
        let text = "RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR;COUNT=10"

        // when
        let rrule = RRuleParser.parse(text)

        // then
        #expect(rrule?.unsupportedKeys.isEmpty == true)
    }
}

// MARK: - 직렬화

extension RRuleParserTests {

    @Test(
        "asRRuleText round trip",
        arguments: [
            "RRULE:FREQ=DAILY;INTERVAL=5",
            "RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR",
            "RRULE:FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=15",
            "RRULE:FREQ=YEARLY;INTERVAL=1;BYMONTH=3;BYMONTHDAY=15;COUNT=10"
        ]
    )
    func asRRuleText_roundTrip(_ text: String) {
        // given
        let rrule = RRuleParser.parse(text)

        // when
        let serialized = rrule?.asRRuleText()

        // then
        #expect(serialized == text)
    }

    @Test func asRRuleText_untilWinsOverCount() {
        // given
        var rule = RRule(freq: .WEEKLY)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        rule.until = formatter.date(from: "20260101T000000Z")
        rule.count = 10

        // when
        let text = rule.asRRuleText()

        // then
        #expect(text.contains("UNTIL=20260101T000000Z") == true)
        #expect(text.contains("COUNT=") == false)
    }
}

// MARK: - recurrence 배열에서 RRULE 줄 교체

extension RRuleParserTests {

    @Test func replacingRRuleLine_keepsOtherLines() {
        // given
        let lines = [
            "RRULE:FREQ=DAILY",
            "EXDATE;TZID=Asia/Seoul:20260101T090000",
            "RDATE:20260201T090000"
        ]

        // when
        let replaced = lines.replacingRRuleLine("RRULE:FREQ=WEEKLY;INTERVAL=2")

        // then
        #expect(replaced == [
            "RRULE:FREQ=WEEKLY;INTERVAL=2",
            "EXDATE;TZID=Asia/Seoul:20260101T090000",
            "RDATE:20260201T090000"
        ])
    }

    @Test func replacingRRuleLine_removesWhenNil() {
        // given
        let lines = [
            "RRULE:FREQ=DAILY",
            "EXDATE;TZID=Asia/Seoul:20260101T090000",
            "RDATE:20260201T090000"
        ]

        // when
        let replaced = lines.replacingRRuleLine(nil)

        // then
        #expect(replaced == [
            "EXDATE;TZID=Asia/Seoul:20260101T090000",
            "RDATE:20260201T090000"
        ])
    }

    @Test func replacingRRuleLine_appendsWhenAbsent() {
        // given
        let lines = ["EXDATE;TZID=Asia/Seoul:20260101T090000"]

        // when
        let replaced = lines.replacingRRuleLine("RRULE:FREQ=DAILY")

        // then
        #expect(replaced == [
            "RRULE:FREQ=DAILY",
            "EXDATE;TZID=Asia/Seoul:20260101T090000"
        ])
    }
}

// MARK: - 애플이 UTC 하루 끝으로 저장한 UNTIL 재앵커링

extension RRuleParserTests {

    private var seoul: TimeZone { TimeZone(identifier: "Asia/Seoul")! }

    private func utcDate(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: text)!
    }

    @Test func reanchorUntil_whenUTCDayEnd_movesToLocalDayEnd() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=DAILY;UNTIL=20260930T235959Z")!

        // when
        let reanchored = rrule.reanchoringUTCDayEndUntil(to: self.seoul)

        // then
        #expect(reanchored.until == self.utcDate("20260930T145959Z"))
    }

    @Test func reanchorUntil_whenNextDayMidnight_movesToPreviousLocalDayEnd() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=DAILY;UNTIL=20261001T000000Z")!

        // when
        let reanchored = rrule.reanchoringUTCDayEndUntil(to: self.seoul)

        // then
        #expect(reanchored.until == self.utcDate("20260930T145959Z"))
    }

    @Test func reanchorUntil_whenNotDayBoundary_keepsUntil() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=DAILY;UNTIL=20260929T230000Z")!

        // when
        let reanchored = rrule.reanchoringUTCDayEndUntil(to: self.seoul)

        // then
        #expect(reanchored.until == self.utcDate("20260929T230000Z"))
    }

    @Test func reanchorUntil_whenCountEnd_keepsCount() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=DAILY;COUNT=10")!

        // when
        let reanchored = rrule.reanchoringUTCDayEndUntil(to: self.seoul)

        // then
        #expect(reanchored.until == nil)
        #expect(reanchored.count == 10)
    }

    @Test func reanchorUntil_isIdempotent() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=DAILY;UNTIL=20260930T235959Z")!

        // when
        let once = rrule.reanchoringUTCDayEndUntil(to: self.seoul)
        let twice = once.reanchoringUTCDayEndUntil(to: self.seoul)

        // then
        #expect(twice.until == once.until)
    }
}
