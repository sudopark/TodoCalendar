//
//  RRuleDisplayTextTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import CommonPresentation


struct RRuleDisplayTextTests {

    @Test func rrule_displayText_weeklyWithUntil_showsFrequencyAndEndOption() throws {
        // given
        let rruleLine = "RRULE:FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261231T235959Z"
        let rrule = try #require(RRuleParser.parse(rruleLine))
        let timeZone = try #require(TimeZone(identifier: "UTC"))
        let startTime = Date(timeIntervalSince1970: 1_700_000_000)

        // when
        let text = rrule.displayText(startTime: startTime, timeZone)

        // then
        let lines = text.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == rrule.frequencyText())
        #expect(lines[1].contains("2026"))
    }

    @Test func rrule_displayText_unsupportedFreq_fallsBackToFrequencyText() throws {
        // given
        let rruleLine = "RRULE:FREQ=MONTHLY;BYMONTHDAY=15;BYDAY=MO"
        let rrule = try #require(RRuleParser.parse(rruleLine))
        let timeZone = try #require(TimeZone(identifier: "UTC"))
        let startTime = Date(timeIntervalSince1970: 1_700_000_000)

        // when
        let text = rrule.displayText(startTime: startTime, timeZone)

        // then
        let asEventRepeating = rrule.asEventRepeating(
            startTime: startTime.timeIntervalSince1970, timeZone: timeZone
        )
        #expect(asEventRepeating == nil)
        #expect(text == rrule.frequencyText())
    }

    @Test func repeatOptionDisplayText_usesRepeatOptionSummary() throws {
        // given
        let timeZone = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startTime = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 10))
        )
        var everyWeek = EventRepeatingOptions.EveryWeek(timeZone)
        everyWeek.interval = 1
        everyWeek.dayOfWeeks = [.monday]
        var repeating = EventRepeating(
            repeatingStartTime: startTime.timeIntervalSince1970, repeatOption: everyWeek
        )
        repeating.repeatingEndOption = .count(5)

        // when
        let text = repeating.repeatOptionDisplayText(timeZone)

        // then
        #expect(text == "Every Week\n5 time(s)")
    }

    @Test func rrule_displayText_unsupportedMonthlyWithLastWeekDay_appendsGenderedLastText() throws {
        // given
        let rruleLine = "RRULE:FREQ=MONTHLY;BYMONTHDAY=15;BYDAY=-1FR"
        let rrule = try #require(RRuleParser.parse(rruleLine))
        let timeZone = try #require(TimeZone(identifier: "UTC"))
        let startTime = Date(timeIntervalSince1970: 1_700_000_000)

        // when
        let text = rrule.displayText(startTime: startTime, timeZone)

        // then
        let asEventRepeating = rrule.asEventRepeating(
            startTime: startTime.timeIntervalSince1970, timeZone: timeZone
        )
        #expect(asEventRepeating == nil)
        let expectedLastText = "eventDetail.repeating.last::m".localized()
        #expect(text.contains("\(expectedLastText) \(DayOfWeeks.friday.shortText)"))
    }

    @Test func summaryText_everyMonthSomeWeekDay_usesGenderedTemplateKey() throws {
        // given
        let timeZone = try #require(TimeZone(identifier: "UTC"))
        var option = EventRepeatingOptions.EveryMonth(timeZone: timeZone)
        option.selection = .week([.seq(3)], [.wednesday])
        let startTime = Date(timeIntervalSince1970: 1_700_000_000)

        // when
        let text = option.summaryText(startTime: startTime, timeZone: timeZone)

        // then
        let expected = "eventDetail.repeating.every3WeekOfEveryMonth::someday::m"
            .localized(with: DayOfWeeks.wednesday.text)
        #expect(text == expected)
    }

    @Test func summaryText_everyMonthLastWeekDay_usesGenderedTemplateKey() throws {
        // given
        let timeZone = try #require(TimeZone(identifier: "UTC"))
        var option = EventRepeatingOptions.EveryMonth(timeZone: timeZone)
        option.selection = .week([.last], [.wednesday])
        let startTime = Date(timeIntervalSince1970: 1_700_000_000)

        // when
        let text = option.summaryText(startTime: startTime, timeZone: timeZone)

        // then
        let expected = "eventDetail.repeating.everyLastWeekOfEveryMonth::someday::m"
            .localized(with: DayOfWeeks.wednesday.text)
        #expect(text == expected)
    }
}
