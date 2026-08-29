//
//  EventShareTextBuilderTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import Extensions

@testable import CalendarScenes


struct EventShareTextBuilderTests {

    private let timeZone = TimeZone(abbreviation: "KST")!

    private func dayStart(year: Int, month: Int, day: Int) -> TimeInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = self.timeZone
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components)?.timeIntervalSince1970 ?? 0
    }

    private func makeBuilder() -> EventShareTextBuilder {
        return EventShareTextBuilder(timeZone: self.timeZone)
    }
}


// MARK: - 단일 날짜 그룹

extension EventShareTextBuilderTests {

    @Test func builder_singleDay_rendersDateHeaderAndBullets() {
        // given
        let day = self.dayStart(year: 2026, month: 8, day: 15)
        let lines = [
            SharePreviewLineModel(eventId: "e1", dayStart: day, name: "팀 스탠드업", timeText: "09:00"),
            SharePreviewLineModel(eventId: "e2", dayStart: day, name: "디자인 리뷰", timeText: "13:00~14:30")
        ]
        let builder = self.makeBuilder()

        // when
        let text = builder.build(lines, in: day..<(day + 86_400), kind: .day, includeTagName: false)

        // then
        let resultLines = text.components(separatedBy: "\n")
        #expect(resultLines.count == 4)
        #expect(resultLines[0].hasPrefix("📅 "))
        #expect(resultLines[1] == "")
        #expect(resultLines[2] == "• 09:00 팀 스탠드업")
        #expect(resultLines[3] == "• 13:00~14:30 디자인 리뷰")
    }

    @Test func builder_excludedLines_areNotRendered() {
        // given
        let day = self.dayStart(year: 2026, month: 8, day: 15)
        let lines = [
            SharePreviewLineModel(eventId: "e1", dayStart: day, name: "팀 스탠드업", timeText: "09:00"),
            SharePreviewLineModel(eventId: "e2", dayStart: day, name: "디자인 리뷰", timeText: "13:00~14:30", isExcluded: true)
        ]
        let builder = self.makeBuilder()

        // when
        let text = builder.build(lines, in: day..<(day + 86_400), kind: .day, includeTagName: false)

        // then
        let resultLines = text.components(separatedBy: "\n")
        #expect(resultLines.count == 3)
        #expect(!resultLines.contains { $0.contains("디자인 리뷰") })
        #expect(resultLines[2] == "• 09:00 팀 스탠드업")
    }

    @Test func builder_lineWithoutTimeText_rendersNameOnly() {
        // given
        let day = self.dayStart(year: 2026, month: 8, day: 15)
        let lines = [
            SharePreviewLineModel(eventId: "e1", dayStart: day, name: "장보기", timeText: nil)
        ]
        let builder = self.makeBuilder()

        // when
        let text = builder.build(lines, in: day..<(day + 86_400), kind: .day, includeTagName: false)

        // then
        let resultLines = text.components(separatedBy: "\n")
        #expect(resultLines[2] == "• 장보기")
    }
}


// MARK: - 태그명 포함 옵션

extension EventShareTextBuilderTests {

    @Test func builder_includeTagName_appendsTagNameSuffix() {
        // given
        let day = self.dayStart(year: 2026, month: 8, day: 15)
        let lines = [
            SharePreviewLineModel(
                eventId: "e1", dayStart: day, name: "장보기", timeText: nil,
                tagId: .custom("personal"), tagName: "개인"
            )
        ]
        let builder = self.makeBuilder()

        // when
        let text = builder.build(lines, in: day..<(day + 86_400), kind: .day, includeTagName: true)

        // then
        let resultLines = text.components(separatedBy: "\n")
        #expect(resultLines[2] == "• 장보기 · 개인")
    }

    @Test func builder_includeTagName_whenTagNameIsNil_rendersNoSuffix() {
        // given
        let day = self.dayStart(year: 2026, month: 8, day: 15)
        let lines = [
            SharePreviewLineModel(eventId: "e1", dayStart: day, name: "장보기", timeText: nil, tagId: nil, tagName: nil)
        ]
        let builder = self.makeBuilder()

        // when
        let text = builder.build(lines, in: day..<(day + 86_400), kind: .day, includeTagName: true)

        // then
        let resultLines = text.components(separatedBy: "\n")
        #expect(resultLines[2] == "• 장보기")
        #expect(!resultLines[2].contains("·"))
    }
}


// MARK: - 여러 날짜 그룹

extension EventShareTextBuilderTests {

    @Test func builder_multipleDays_rendersGroupHeaderPerDay() {
        // given
        let day1 = self.dayStart(year: 2026, month: 8, day: 15)
        let day2 = self.dayStart(year: 2026, month: 8, day: 16)
        let lines = [
            SharePreviewLineModel(eventId: "e1", dayStart: day1, name: "팀 스탠드업", timeText: "09:00"),
            SharePreviewLineModel(eventId: "e2", dayStart: day2, name: "워크숍", timeText: "종일")
        ]
        let builder = self.makeBuilder()

        // when
        let text = builder.build(lines, in: day1..<(day2 + 86_400), kind: .month, includeTagName: false)

        // then
        let resultLines = text.components(separatedBy: "\n")
        #expect(resultLines.count == 7)
        #expect(resultLines[0].hasPrefix("📅 "))
        #expect(resultLines[1] == "")
        #expect(resultLines[2].hasPrefix("▸ "))
        #expect(resultLines[3] == "• 09:00 팀 스탠드업")
        #expect(resultLines[4] == "")
        #expect(resultLines[5].hasPrefix("▸ "))
        #expect(resultLines[6] == "• 종일 워크숍")
    }

    @Test func builder_undatedTodos_renderBeforeAnyDayGroup() {
        // given
        let day1 = self.dayStart(year: 2026, month: 8, day: 15)
        let day2 = self.dayStart(year: 2026, month: 8, day: 16)
        let lines = [
            SharePreviewLineModel(eventId: "e1", dayStart: day1, name: "팀 스탠드업", timeText: "09:00"),
            SharePreviewLineModel(eventId: "t1", dayStart: nil, name: "장보기", isTodo: true),
            SharePreviewLineModel(eventId: "e2", dayStart: day2, name: "워크숍", timeText: "종일")
        ]
        let builder = self.makeBuilder()

        // when
        let text = builder.build(lines, in: day1..<(day2 + 86_400), kind: .month, includeTagName: false)

        // then
        let resultLines = text.components(separatedBy: "\n")
        #expect(resultLines[2] == "• \(R.String.calendarEventTimeTodo) 장보기")
        #expect(resultLines[3] == "")
        #expect(resultLines[4].hasPrefix("▸ "))
    }
}


// MARK: - 할일 라벨

extension EventShareTextBuilderTests {

    @Test func builder_todoLine_prependsTodoLabelBeforeTime() {
        // given
        let day = self.dayStart(year: 2026, month: 8, day: 15)
        let lines = [
            SharePreviewLineModel(eventId: "e1", dayStart: day, name: "병원 예약", timeText: "09:00", isTodo: true)
        ]
        let builder = self.makeBuilder()

        // when
        let text = builder.build(lines, in: day..<(day + 86_400), kind: .day, includeTagName: false)

        // then
        let resultLines = text.components(separatedBy: "\n")
        #expect(resultLines[2] == "• \(R.String.calendarEventTimeTodo) 09:00 병원 예약")
    }

    @Test func builder_todoLineWithoutTime_prependsTodoLabelBeforeName() {
        // given
        let day = self.dayStart(year: 2026, month: 8, day: 15)
        let lines = [
            SharePreviewLineModel(eventId: "e1", dayStart: day, name: "장보기", timeText: nil, isTodo: true)
        ]
        let builder = self.makeBuilder()

        // when
        let text = builder.build(lines, in: day..<(day + 86_400), kind: .day, includeTagName: false)

        // then
        let resultLines = text.components(separatedBy: "\n")
        #expect(resultLines[2] == "• \(R.String.calendarEventTimeTodo) 장보기")
    }

    @Test func builder_scheduleLine_hasNoTodoLabel() {
        // given
        let day = self.dayStart(year: 2026, month: 8, day: 15)
        let lines = [
            SharePreviewLineModel(eventId: "e1", dayStart: day, name: "팀 스탠드업", timeText: "09:00", isTodo: false)
        ]
        let builder = self.makeBuilder()

        // when
        let text = builder.build(lines, in: day..<(day + 86_400), kind: .day, includeTagName: false)

        // then
        let resultLines = text.components(separatedBy: "\n")
        #expect(resultLines[2] == "• 09:00 팀 스탠드업")
        #expect(!resultLines[2].contains(R.String.calendarEventTimeTodo))
    }
}


// MARK: - 빈 결과

extension EventShareTextBuilderTests {

    @Test func builder_allLinesExcluded_returnsEmptyString() {
        // given
        let day = self.dayStart(year: 2026, month: 8, day: 15)
        let lines = [
            SharePreviewLineModel(eventId: "e1", dayStart: day, name: "장보기", timeText: nil, isExcluded: true)
        ]
        let builder = self.makeBuilder()

        // when
        let text = builder.build(lines, in: day..<(day + 86_400), kind: .day, includeTagName: false)

        // then
        #expect(text == "")
    }

    @Test func builder_emptyLines_returnsEmptyString() {
        // given
        let day = self.dayStart(year: 2026, month: 8, day: 15)
        let lines: [SharePreviewLineModel] = []
        let builder = self.makeBuilder()

        // when
        let text = builder.build(lines, in: day..<(day + 86_400), kind: .day, includeTagName: false)

        // then
        #expect(text == "")
    }
}
