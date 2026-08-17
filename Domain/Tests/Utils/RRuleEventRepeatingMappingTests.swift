//
//  RRuleEventRepeatingMappingTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics
import Extensions
import UnitTestHelpKit

@testable import Domain

private let testTimeZone = TimeZone(abbreviation: "KST")!
private let testStartTime: TimeInterval = 1773532800   // 2026-03-15 09:00:00 KST, Sunday

struct RRuleEventRepeatingMappingTests { }


// MARK: - RRULE → 앱 옵션

extension RRuleEventRepeatingMappingTests {

    @Test func asEventRepeating_everyDay() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=DAILY;INTERVAL=3")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        let expected = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        )
        #expect(repeating == expected)
    }

    @Test func asEventRepeating_everyWeek() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        let expected = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryWeek(testTimeZone)
                |> \.interval .~ 2
                |> \.dayOfWeeks .~ [.monday, .friday]
        )
        #expect(repeating == expected)
    }

    @Test func asEventRepeating_everyMonthByDays() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=15")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        let expected = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryMonth(timeZone: testTimeZone)
                |> \.interval .~ 1
                |> \.selection .~ .days([15])
        )
        #expect(repeating == expected)
    }

    @Test func asEventRepeating_everyMonthByWeek() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=MONTHLY;INTERVAL=1;BYDAY=1MO,-1MO")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        let expected = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryMonth(timeZone: testTimeZone)
                |> \.interval .~ 1
                |> \.selection .~ .week([.seq(1), .last], [.monday])
        )
        #expect(repeating == expected)
    }

    @Test func asEventRepeating_everyYearSomeDay() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=YEARLY;INTERVAL=1;BYMONTH=3;BYMONTHDAY=15")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        let expected = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryYearSomeDay(testTimeZone, 3, 15)
                |> \.interval .~ 1
        )
        #expect(repeating == expected)
    }

    @Test func asEventRepeating_everyYearByWeek() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=YEARLY;INTERVAL=1;BYMONTH=3;BYDAY=1MO,-1MO")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        let expected = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryYear(timeZone: testTimeZone)
                |> \.interval .~ 1
                |> \.months .~ [.march]
                |> \.weekOrdinals .~ [.seq(1), .last]
                |> \.dayOfWeek .~ [.monday]
        )
        #expect(repeating == expected)
    }

    @Test func asEventRepeating_weeklyWithoutByDay_usesStartWeekday() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=WEEKLY;INTERVAL=1")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        let expected = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryWeek(testTimeZone)
                |> \.interval .~ 1
                |> \.dayOfWeeks .~ [.sunday]
        )
        #expect(repeating == expected)
    }

    @Test func asEventRepeating_monthlyWithoutSelectors_usesStartDay() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=MONTHLY;INTERVAL=1")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        let expected = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryMonth(timeZone: testTimeZone)
                |> \.interval .~ 1
                |> \.selection .~ .days([15])
        )
        #expect(repeating == expected)
    }

    @Test func asEventRepeating_everyYearWithoutSelectors_usesStartMonthDay() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=YEARLY;INTERVAL=2")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        let expected = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryYearSomeDay(testTimeZone, 3, 15)
                |> \.interval .~ 2
        )
        #expect(repeating == expected)
    }

    @Test func asEventRepeating_untilBecomesEndOption() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=DAILY;INTERVAL=1;UNTIL=20260401T000000Z")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        #expect(repeating?.repeatingEndOption?.endTime != nil)
        #expect(repeating?.repeatingEndOption?.endCount == nil)
    }

    @Test func asEventRepeating_countBecomesEndOption() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=DAILY;INTERVAL=1;COUNT=5")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        #expect(repeating?.repeatingEndOption?.endCount == 5)
        #expect(repeating?.repeatingEndOption?.endTime == nil)
    }

    @Test func asEventRepeating_whenUnsupportedKeyExists_isNil() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=MONTHLY;BYSETPOS=-1;BYDAY=MO")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        #expect(repeating == nil)
    }

    @Test func asEventRepeating_whenByDayOrdinalMixed_isNil() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=MONTHLY;BYDAY=1MO,FR")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        #expect(repeating == nil)
    }

    @Test func asEventRepeating_whenByMonthDayIsNegative_isNil() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=MONTHLY;BYMONTHDAY=-1")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        #expect(repeating == nil)
    }

    @Test func asEventRepeating_whenYearlyByMonthDayIsNegative_isNil() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=-1")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        #expect(repeating == nil)
    }

    @Test func asEventRepeating_whenByMonthIsOutOfRange_isNil() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=YEARLY;BYMONTH=13;BYMONTHDAY=15")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        #expect(repeating == nil)
    }

    @Test func asEventRepeating_whenIntervalIsZero_isNil() {
        // given
        let rrule = RRuleParser.parse("RRULE:FREQ=DAILY;INTERVAL=0")

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)

        // then
        #expect(repeating == nil)
    }
}


// MARK: - 앱 옵션 → RRULE

extension RRuleEventRepeatingMappingTests {

    @Test func asRRuleText_everyDay() {
        // given
        let repeating = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        )

        // when
        let text = repeating.asRRuleText(testTimeZone)

        // then
        #expect(text == "RRULE:FREQ=DAILY;INTERVAL=3")
    }

    @Test func asRRuleText_everyWeek() {
        // given
        let repeating = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryWeek(testTimeZone)
                |> \.interval .~ 2
                |> \.dayOfWeeks .~ [.monday, .friday]
        )

        // when
        let text = repeating.asRRuleText(testTimeZone)

        // then
        #expect(text == "RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR")
    }

    @Test func asRRuleText_everyMonthByDays() {
        // given
        let repeating = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryMonth(timeZone: testTimeZone)
                |> \.interval .~ 1
                |> \.selection .~ .days([15])
        )

        // when
        let text = repeating.asRRuleText(testTimeZone)

        // then
        #expect(text == "RRULE:FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=15")
    }

    @Test func asRRuleText_everyMonthByWeek() {
        // given
        let repeating = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryMonth(timeZone: testTimeZone)
                |> \.interval .~ 1
                |> \.selection .~ .week([.seq(1), .last], [.monday])
        )

        // when
        let text = repeating.asRRuleText(testTimeZone)

        // then
        #expect(text == "RRULE:FREQ=MONTHLY;INTERVAL=1;BYDAY=1MO,-1MO")
    }

    @Test func asRRuleText_everyYear() {
        // given
        let repeating = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryYear(timeZone: testTimeZone)
                |> \.interval .~ 1
                |> \.months .~ [.march]
                |> \.weekOrdinals .~ [.seq(1), .last]
                |> \.dayOfWeek .~ [.monday]
        )

        // when
        let text = repeating.asRRuleText(testTimeZone)

        // then
        #expect(text == "RRULE:FREQ=YEARLY;INTERVAL=1;BYMONTH=3;BYDAY=1MO,-1MO")
    }

    @Test func asRRuleText_everyYearSomeDay() {
        // given
        let repeating = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryYearSomeDay(testTimeZone, 3, 15)
                |> \.interval .~ 1
        )

        // when
        let text = repeating.asRRuleText(testTimeZone)

        // then
        #expect(text == "RRULE:FREQ=YEARLY;INTERVAL=1;BYMONTH=3;BYMONTHDAY=15")
    }

    @Test func asRRuleText_lunarCalendar_isNil() {
        // given
        let repeating = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.LunarCalendarEveryYear(testTimeZone, 3, 15)
        )

        // when
        let text = repeating.asRRuleText(testTimeZone)

        // then
        #expect(text == nil)
    }

    @Test func asRRuleText_everyWeekWithoutDays_isNil() {
        // given
        let repeating = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryWeek(testTimeZone)
        )

        // when
        let text = repeating.asRRuleText(testTimeZone)

        // then
        #expect(text == nil)
    }

    @Test func asRRuleText_endOptionUntil() {
        // given
        let repeating = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryDay() |> \.interval .~ 1
        )
        |> \.repeatingEndOption .~ .until(testStartTime + .days(30))

        // when
        let text = repeating.asRRuleText(testTimeZone)

        // then
        #expect(text?.contains("UNTIL=") == true)
        #expect(text?.contains("COUNT=") == false)
    }

    @Test func asRRuleText_endOptionCount() {
        // given
        let repeating = EventRepeating(
            repeatingStartTime: testStartTime,
            repeatOption: EventRepeatingOptions.EveryDay() |> \.interval .~ 1
        )
        |> \.repeatingEndOption .~ .count(5)

        // when
        let text = repeating.asRRuleText(testTimeZone)

        // then
        #expect(text?.contains("COUNT=5") == true)
        #expect(text?.contains("UNTIL=") == false)
    }
}


// MARK: - 왕복

extension RRuleEventRepeatingMappingTests {

    @Test(
        "RRULE round trip through app repeat options",
        arguments: [
            "RRULE:FREQ=DAILY;INTERVAL=5",
            "RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR",
            "RRULE:FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=15",
            "RRULE:FREQ=MONTHLY;INTERVAL=1;BYDAY=1MO,-1MO",
            "RRULE:FREQ=YEARLY;INTERVAL=1;BYMONTH=3;BYMONTHDAY=15;COUNT=10",
            "RRULE:FREQ=YEARLY;INTERVAL=1;BYMONTH=3;BYDAY=1MO,-1MO"
        ]
    )
    func roundTrip_preservesRule(_ text: String) {
        // given
        let rrule = RRuleParser.parse(text)

        // when
        let repeating = rrule?.asEventRepeating(startTime: testStartTime, timeZone: testTimeZone)
        let serialized = repeating?.asRRuleText(testTimeZone)

        // then
        #expect(serialized == text)
    }
}
