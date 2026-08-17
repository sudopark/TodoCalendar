//
//  AppleCalendarRecurrenceRuleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 4/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import EventKit
@testable import Repository


struct AppleCalendarRecurrenceRuleTests {

    @Test func daily_simpleRule() {
        // given
        let rule = EKRecurrenceRule(
            recurrenceWith: .daily, interval: 1,
            daysOfTheWeek: nil, daysOfTheMonth: nil,
            monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil, end: nil
        )
        // when
        let rrule = rule.toRRuleString()
        // then
        #expect(rrule == "RRULE:FREQ=DAILY;INTERVAL=1")
    }

    @Test func weekly_withDays() {
        // given
        let rule = EKRecurrenceRule(
            recurrenceWith: .weekly, interval: 2,
            daysOfTheWeek: [.init(.monday), .init(.friday)],
            daysOfTheMonth: nil, monthsOfTheYear: nil,
            weeksOfTheYear: nil, daysOfTheYear: nil,
            setPositions: nil, end: nil
        )
        // when
        let rrule = rule.toRRuleString()
        // then
        #expect(rrule == "RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR")
    }

    @Test func monthly_withDaysOfMonth() {
        // given
        let rule = EKRecurrenceRule(
            recurrenceWith: .monthly, interval: 1,
            daysOfTheWeek: nil, daysOfTheMonth: [1, 15, -1],
            monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil, end: nil
        )
        // when
        let rrule = rule.toRRuleString()
        // then
        #expect(rrule == "RRULE:FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=1,15,-1")
    }

    @Test func monthly_withNthDayOfWeek() {
        // given
        let rule = EKRecurrenceRule(
            recurrenceWith: .monthly, interval: 1,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(.tuesday, weekNumber: 2)],
            daysOfTheMonth: nil, monthsOfTheYear: nil,
            weeksOfTheYear: nil, daysOfTheYear: nil,
            setPositions: nil, end: nil
        )
        // when
        let rrule = rule.toRRuleString()
        // then
        #expect(rrule == "RRULE:FREQ=MONTHLY;INTERVAL=1;BYDAY=2TU")
    }

    @Test func monthly_withEnd_count() {
        // given
        let rule = EKRecurrenceRule(
            recurrenceWith: .monthly, interval: 1,
            daysOfTheWeek: nil, daysOfTheMonth: nil,
            monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil,
            end: EKRecurrenceEnd(occurrenceCount: 10)
        )
        // when
        let rrule = rule.toRRuleString()
        // then
        #expect(rrule == "RRULE:FREQ=MONTHLY;INTERVAL=1;COUNT=10")
    }

    @Test func yearly_withEnd_until() {
        // given
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        let endDate = formatter.date(from: "2026-12-31")!
        let rule = EKRecurrenceRule(
            recurrenceWith: .yearly, interval: 1,
            daysOfTheWeek: nil, daysOfTheMonth: nil,
            monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil,
            end: EKRecurrenceEnd(end: endDate)
        )
        // when
        let rrule = rule.toRRuleString()
        // then
        #expect(rrule == "RRULE:FREQ=YEARLY;INTERVAL=1;UNTIL=20261231T000000Z")
    }

    @Test func yearly_withMonthsAndDaysOfWeek() {
        // given
        let rule = EKRecurrenceRule(
            recurrenceWith: .yearly, interval: 1,
            daysOfTheWeek: [.init(.thursday, weekNumber: 4)],
            daysOfTheMonth: nil, monthsOfTheYear: [11],
            weeksOfTheYear: nil, daysOfTheYear: nil,
            setPositions: nil, end: nil
        )
        // when
        let rrule = rule.toRRuleString()
        // then
        #expect(rrule == "RRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=4TH;BYMONTH=11")
    }

    @Test func yearly_withWeeksOfYear() {
        // given
        let rule = EKRecurrenceRule(
            recurrenceWith: .yearly, interval: 1,
            daysOfTheWeek: nil, daysOfTheMonth: nil,
            monthsOfTheYear: nil, weeksOfTheYear: [1, -1],
            daysOfTheYear: nil, setPositions: nil, end: nil
        )
        // when
        let rrule = rule.toRRuleString()
        // then
        #expect(rrule == "RRULE:FREQ=YEARLY;INTERVAL=1;BYWEEKNO=1,-1")
    }

    @Test func yearly_withDaysOfYear() {
        // given
        let rule = EKRecurrenceRule(
            recurrenceWith: .yearly, interval: 1,
            daysOfTheWeek: nil, daysOfTheMonth: nil,
            monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: [100, -1], setPositions: nil, end: nil
        )
        // when
        let rrule = rule.toRRuleString()
        // then
        #expect(rrule == "RRULE:FREQ=YEARLY;INTERVAL=1;BYYEARDAY=100,-1")
    }

    @Test func monthly_withSetPositions() {
        // given
        let rule = EKRecurrenceRule(
            recurrenceWith: .monthly, interval: 1,
            daysOfTheWeek: [.init(.monday), .init(.tuesday), .init(.wednesday), .init(.thursday), .init(.friday)],
            daysOfTheMonth: nil, monthsOfTheYear: nil,
            weeksOfTheYear: nil, daysOfTheYear: nil,
            setPositions: [-1], end: nil
        )
        // when
        let rrule = rule.toRRuleString()
        // then
        #expect(rrule == "RRULE:FREQ=MONTHLY;INTERVAL=1;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1")
    }
}


// MARK: - RRULE string → EKRecurrenceRule

extension AppleCalendarRecurrenceRuleTests {

    private func utcDate(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.date(from: text)!
    }

    @Test func initFromRRuleText_weekly() throws {
        // given
        let text = "RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR"
        // when
        let rule = try #require(EKRecurrenceRule(rruleText: text))
        // then
        #expect(rule.frequency == .weekly)
        #expect(rule.interval == 2)
        #expect(rule.daysOfTheWeek?.map { $0.dayOfTheWeek } == [.monday, .friday])
        #expect(rule.daysOfTheWeek?.map { $0.weekNumber } == [0, 0])
        #expect(rule.daysOfTheMonth == nil)
        #expect(rule.monthsOfTheYear == nil)
        #expect(rule.recurrenceEnd == nil)
    }

    @Test func initFromRRuleText_monthlyByMonthDay() throws {
        // given
        let text = "RRULE:FREQ=MONTHLY;BYMONTHDAY=15"
        // when
        let rule = try #require(EKRecurrenceRule(rruleText: text))
        // then
        #expect(rule.frequency == .monthly)
        #expect(rule.interval == 1)
        #expect(rule.daysOfTheMonth?.map { $0.intValue } == [15])
        #expect(rule.daysOfTheWeek == nil)
    }

    @Test func initFromRRuleText_yearlyByMonthAndMonthDay() throws {
        // given
        let text = "RRULE:FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=15"
        // when
        let rule = try #require(EKRecurrenceRule(rruleText: text))
        // then
        #expect(rule.frequency == .yearly)
        #expect(rule.monthsOfTheYear?.map { $0.intValue } == [3])
        #expect(rule.daysOfTheMonth?.map { $0.intValue } == [15])
    }

    @Test func initFromRRuleText_ordinalByDay() throws {
        // given
        let text = "RRULE:FREQ=MONTHLY;BYDAY=2TU"
        // when
        let rule = try #require(EKRecurrenceRule(rruleText: text))
        // then
        #expect(rule.daysOfTheWeek?.map { $0.dayOfTheWeek } == [.tuesday])
        #expect(rule.daysOfTheWeek?.map { $0.weekNumber } == [2])
    }

    @Test func initFromRRuleText_lastOrdinalByDay() throws {
        // given - 매월 마지막 수요일
        let text = "RRULE:FREQ=MONTHLY;BYDAY=-1WE"
        // when
        let rule = try #require(EKRecurrenceRule(rruleText: text))
        // then
        #expect(rule.daysOfTheWeek?.map { $0.dayOfTheWeek } == [.wednesday])
        #expect(rule.daysOfTheWeek?.map { $0.weekNumber } == [-1])
    }

    @Test func initFromRRuleText_until() throws {
        // given
        let text = "RRULE:FREQ=DAILY;INTERVAL=1;UNTIL=20261231T000000Z"
        // when
        let rule = try #require(EKRecurrenceRule(rruleText: text))
        // then
        #expect(rule.recurrenceEnd?.endDate == utcDate("20261231T000000Z"))
        #expect(rule.recurrenceEnd?.occurrenceCount == 0)
    }

    @Test func initFromRRuleText_count() throws {
        // given
        let text = "RRULE:FREQ=DAILY;INTERVAL=1;COUNT=10"
        // when
        let rule = try #require(EKRecurrenceRule(rruleText: text))
        // then
        #expect(rule.recurrenceEnd?.occurrenceCount == 10)
        #expect(rule.recurrenceEnd?.endDate == nil)
    }

    @Test func initFromRRuleText_whenUnsupportedKeyExists_isNil() {
        // given
        let text = "RRULE:FREQ=MONTHLY;BYSETPOS=-1;BYDAY=MO"
        // when
        let rule = EKRecurrenceRule(rruleText: text)
        // then
        #expect(rule == nil)
    }

    @Test func initFromRRuleText_whenIntervalIsZero_isNil() {
        // given
        let text = "RRULE:FREQ=DAILY;INTERVAL=0"
        // when
        let rule = EKRecurrenceRule(rruleText: text)
        // then
        #expect(rule == nil)
    }

    @Test func initFromRRuleText_whenTextIsNotRRule_isNil() {
        // given
        let text = "FREQ=DAILY;INTERVAL=1"
        // when
        let rule = EKRecurrenceRule(rruleText: text)
        // then
        #expect(rule == nil)
    }

    @Test func roundTrip_ekRuleToTextToEkRule() throws {
        // given
        let origin = EKRecurrenceRule(
            recurrenceWith: .monthly, interval: 3,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(.tuesday, weekNumber: 2)],
            daysOfTheMonth: nil, monthsOfTheYear: nil,
            weeksOfTheYear: nil, daysOfTheYear: nil,
            setPositions: nil, end: EKRecurrenceEnd(occurrenceCount: 5)
        )
        // when
        let restored = try #require(EKRecurrenceRule(rruleText: origin.toRRuleString()))
        // then
        #expect(restored.frequency == origin.frequency)
        #expect(restored.interval == origin.interval)
        #expect(restored.daysOfTheWeek?.map { $0.dayOfTheWeek } == [.tuesday])
        #expect(restored.daysOfTheWeek?.map { $0.weekNumber } == [2])
        #expect(restored.recurrenceEnd?.occurrenceCount == 5)
        #expect(restored.toRRuleString() == origin.toRRuleString())
    }
}
