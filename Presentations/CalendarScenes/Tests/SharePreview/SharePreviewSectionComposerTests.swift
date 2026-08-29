//
//  SharePreviewSectionComposerTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Extensions

@testable import CalendarScenes


final class SharePreviewSectionComposerTests {

    private let timeZone: TimeZone = TimeZone(abbreviation: "KST")!

    private var calendar: Calendar {
        return Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        return self.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func weekRange(startingAt start: Date) -> Range<TimeInterval> {
        let end = self.calendar.date(byAdding: .day, value: 7, to: start)!
        return start.timeIntervalSince1970..<end.timeIntervalSince1970
    }

    private func twoSections(in range: Range<TimeInterval>) -> [SharePreviewSectionModel] {
        return [
            .init(dayStart: range.lowerBound, dayHeaderText: "day1", lines: []),
            .init(dayStart: range.lowerBound + 3600 * 24, dayHeaderText: "day2", lines: [])
        ]
    }

    private func makeComposer(now: Date) -> SharePreviewSectionComposer {
        return SharePreviewSectionComposer(timeZone: self.timeZone, now: now)
    }
}


// MARK: - 주 단위 헤더

extension SharePreviewSectionComposerTests {

    // 2026-08-10(월)부터 한 주 — 8월 1일이 속한 주(7/27~8/2)가 8월 1주라 3주차다
    private var augustThirdWeek: Range<TimeInterval> {
        return self.weekRange(startingAt: self.date(2026, 8, 10))
    }

    @Test func composer_whenNowIsInSharedWeek_headerIsThisWeek() {
        // given
        let range = self.augustThirdWeek
        let composer = self.makeComposer(now: self.date(2026, 8, 13))

        // when
        let header = composer.rangeHeaderText(of: self.twoSections(in: range), in: range, kind: .week)

        // then
        #expect(header == "share_preview::header::this_week".localized())
    }

    @Test func composer_whenSharedWeekIsBeforeNowWeek_headerIsLastWeek() {
        // given
        let range = self.augustThirdWeek
        let composer = self.makeComposer(now: self.date(2026, 8, 19))

        // when
        let header = composer.rangeHeaderText(of: self.twoSections(in: range), in: range, kind: .week)

        // then
        #expect(header == "share_preview::header::last_week".localized())
    }

    @Test func composer_whenSharedWeekIsAfterNowWeek_headerIsNextWeek() {
        // given
        let range = self.augustThirdWeek
        let composer = self.makeComposer(now: self.date(2026, 8, 5))

        // when
        let header = composer.rangeHeaderText(of: self.twoSections(in: range), in: range, kind: .week)

        // then
        #expect(header == "share_preview::header::next_week".localized())
    }

    @Test func composer_whenSharedWeekIsFarFromNow_headerIsWeekOrdinalOfStartingMonth() {
        // given
        let range = self.augustThirdWeek
        let composer = self.makeComposer(now: self.date(2026, 10, 1))

        // when
        let header = composer.rangeHeaderText(of: self.twoSections(in: range), in: range, kind: .week)

        // then
        let formatter = DateFormatter() |> \.timeZone .~ self.timeZone
        formatter.dateFormat = "date_form.MMM".localized()
        let monthText = formatter.string(from: self.date(2026, 8, 10))
        #expect(header == "share_preview::header::week_of_month".localized(with: monthText, 3))
    }

    // 7/27~8/2 주는 시작일이 7월이라 7월 기준 — 7/1이 속한 주(6/29~)가 1주라 5주차다
    @Test func composer_whenWeekSpansTwoMonths_ordinalFollowsStartingMonth() {
        // given
        let range = self.weekRange(startingAt: self.date(2026, 7, 27))
        let composer = self.makeComposer(now: self.date(2026, 10, 1))

        // when
        let header = composer.rangeHeaderText(of: self.twoSections(in: range), in: range, kind: .week)

        // then
        let formatter = DateFormatter() |> \.timeZone .~ self.timeZone
        formatter.dateFormat = "date_form.MMM".localized()
        let monthText = formatter.string(from: self.date(2026, 7, 27))
        #expect(header == "share_preview::header::week_of_month".localized(with: monthText, 5))
    }

    @Test func composer_whenKindIsMonth_headerIsMonthTextRegardlessOfNow() {
        // given
        let range = self.augustThirdWeek
        let composer = self.makeComposer(now: self.date(2026, 8, 13))

        // when
        let header = composer.rangeHeaderText(of: self.twoSections(in: range), in: range, kind: .month)

        // then
        let formatter = DateFormatter() |> \.timeZone .~ self.timeZone
        formatter.dateFormat = "date_form.MMM_yyyy".localized()
        #expect(header == formatter.string(from: self.date(2026, 8, 10)))
    }
}


// MARK: - 날짜 섹션 분리

extension SharePreviewSectionComposerTests {

    private func line(_ eventId: String, dayStart: TimeInterval?) -> SharePreviewLineModel {
        return .init(eventId: eventId, dayStart: dayStart, name: eventId)
    }

    @Test func composer_whenAllLinesOnSameDay_makesOneSectionWithoutDayHeader() {
        // given
        let dayStart = self.date(2026, 8, 10).timeIntervalSince1970
        let composer = self.makeComposer(now: self.date(2026, 8, 10))

        // when
        let sections = composer.sections(of: [
            self.line("e1", dayStart: dayStart), self.line("e2", dayStart: dayStart)
        ])

        // then
        #expect(sections.count == 1)
        #expect(sections.first?.dayHeaderText == nil)
        #expect(sections.first?.lines.count == 2)
    }

    @Test func composer_undatedLines_becomeLeadingSectionWithoutDayHeader() {
        // given
        let day10 = self.date(2026, 8, 10).timeIntervalSince1970
        let day12 = self.date(2026, 8, 12).timeIntervalSince1970
        let composer = self.makeComposer(now: self.date(2026, 8, 10))

        // when
        let sections = composer.sections(of: [
            self.line("dated", dayStart: day10),
            self.line("undated", dayStart: nil),
            self.line("later", dayStart: day12)
        ])

        // then
        #expect(sections.first?.dayStart == nil)
        #expect(sections.first?.dayHeaderText == nil)
        #expect(sections.first?.lines.map { $0.eventId } == ["undated"])
        #expect(sections.dropFirst().compactMap { $0.dayStart } == [day10, day12])
    }

    @Test func composer_whenLinesSpanDays_splitsPerDaySortedWithDayHeader() {
        // given
        let day10 = self.date(2026, 8, 10).timeIntervalSince1970
        let day12 = self.date(2026, 8, 12).timeIntervalSince1970
        let composer = self.makeComposer(now: self.date(2026, 8, 10))

        // when
        let sections = composer.sections(of: [
            self.line("later", dayStart: day12), self.line("earlier", dayStart: day10)
        ])

        // then
        #expect(sections.map { $0.dayStart } == [day10, day12])
        #expect(sections.allSatisfy { $0.dayHeaderText?.hasPrefix("▸ ") == true })
        #expect(sections.first?.lines.map { $0.eventId } == ["earlier"])
    }
}
