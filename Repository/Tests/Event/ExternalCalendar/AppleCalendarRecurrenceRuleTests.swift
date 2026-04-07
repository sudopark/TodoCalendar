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
