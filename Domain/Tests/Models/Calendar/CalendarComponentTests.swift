//
//  CalendarComponentTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics

@testable import Domain


struct CalendarComponentTests {

    private let utc = TimeZone(identifier: "UTC")!
    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    private func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarComponent.Day {
        return .init(year: year, month: month, day: day, weekDay: 1)
    }

    private func dayRange(_ year: Int, _ month: Int, _ day: Int, _ timeZone: TimeZone) -> Range<TimeInterval>? {
        return self.day(year, month, day).dayRange(timeZone)
    }
}


// MARK: - Week.range

extension CalendarComponentTests {

    @Test("7일짜리 주의 range는 첫날 00:00부터 마지막날 23:59:59까지다")
    func week_range_spansFromFirstDayStartToLastDayEnd() throws {
        // given
        let days = (10...16).map { self.day(2026, 8, $0) }
        let week = CalendarComponent.Week(days: days)

        // when
        let range = try #require(week.range(self.utc))

        // then
        let expectedStart = try #require(self.dayRange(2026, 8, 10, self.utc)?.lowerBound)
        let expectedEnd = try #require(self.dayRange(2026, 8, 16, self.utc)?.upperBound)
        #expect(range.lowerBound == expectedStart)
        #expect(range.upperBound == expectedEnd)
    }

    @Test("days가 비어 있으면 nil을 반환한다")
    func week_range_whenDaysAreEmpty_returnsNil() {
        // given
        let week = CalendarComponent.Week(days: [])

        // when
        let range = week.range(self.utc)

        // then
        #expect(range == nil)
    }

    @Test("timeZone을 반영해 경계가 이동한다")
    func week_range_respectsTimeZone() throws {
        // given
        let days = (10...16).map { self.day(2026, 8, $0) }
        let week = CalendarComponent.Week(days: days)

        // when
        let utcRange = try #require(week.range(self.utc))
        let seoulRange = try #require(week.range(self.seoul))

        // then
        #expect(utcRange.lowerBound - seoulRange.lowerBound == 9 * 3600)
        #expect(utcRange.upperBound - seoulRange.upperBound == 9 * 3600)
    }
}


// MARK: - CalendarComponent.monthRange

extension CalendarComponentTests {

    @Test("8/1 00:00부터 8/31 23:59:59까지고, 그리드에 딸린 7월·9월 날짜는 포함하지 않는다")
    func monthRange_coversFirstDayToLastDayOfMonth() throws {
        // given
        let fringeWeekWithPreviousMonth = CalendarComponent.Week(
            days: (26...31).map { self.day(2026, 7, $0) } + [self.day(2026, 8, 1)]
        )
        let fringeWeekWithNextMonth = CalendarComponent.Week(
            days: [self.day(2026, 8, 30), self.day(2026, 8, 31)] + (1...5).map { self.day(2026, 9, $0) }
        )
        let component = CalendarComponent(
            year: 2026, month: 8, weeks: [fringeWeekWithPreviousMonth, fringeWeekWithNextMonth]
        )

        // when
        let range = try #require(component.monthRange(self.utc))

        // then
        let expectedStart = try #require(self.dayRange(2026, 8, 1, self.utc)?.lowerBound)
        let expectedEnd = try #require(self.dayRange(2026, 8, 31, self.utc)?.upperBound)
        #expect(range.lowerBound == expectedStart)
        #expect(range.upperBound == expectedEnd)

        let julyFringeDay = try #require(self.dayRange(2026, 7, 31, self.utc))
        let septemberFringeDay = try #require(self.dayRange(2026, 9, 1, self.utc))
        #expect(julyFringeDay.upperBound <= range.lowerBound)
        #expect(septemberFringeDay.lowerBound >= range.upperBound)
    }

    @Test("2024년 2월(윤년)은 29일에서 끝난다")
    func monthRange_forFebruary_leapYear_endsOnDay29() throws {
        // given
        let component = CalendarComponent(
            year: 2024, month: 2, weeks: [CalendarComponent.Week(days: [self.day(2024, 2, 1)])]
        )

        // when
        let range = try #require(component.monthRange(self.utc))

        // then
        let expectedEnd = try #require(self.dayRange(2024, 2, 29, self.utc)?.upperBound)
        #expect(range.upperBound == expectedEnd)
    }

    @Test("2026년 2월(평년)은 28일에서 끝난다")
    func monthRange_forFebruary_commonYear_endsOnDay28() throws {
        // given
        let component = CalendarComponent(
            year: 2026, month: 2, weeks: [CalendarComponent.Week(days: [self.day(2026, 2, 1)])]
        )

        // when
        let range = try #require(component.monthRange(self.utc))

        // then
        let expectedEnd = try #require(self.dayRange(2026, 2, 28, self.utc)?.upperBound)
        #expect(range.upperBound == expectedEnd)
    }

    @Test("timeZone을 반영해 경계가 이동한다")
    func monthRange_respectsTimeZone() throws {
        // given
        let component = CalendarComponent(
            year: 2026, month: 8, weeks: [CalendarComponent.Week(days: [self.day(2026, 8, 1)])]
        )

        // when
        let utcRange = try #require(component.monthRange(self.utc))
        let seoulRange = try #require(component.monthRange(self.seoul))

        // then
        #expect(utcRange.lowerBound - seoulRange.lowerBound == 9 * 3600)
        #expect(utcRange.upperBound - seoulRange.upperBound == 9 * 3600)
    }
}
