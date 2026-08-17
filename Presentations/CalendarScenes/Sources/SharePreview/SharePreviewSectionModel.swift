//
//  SharePreviewSectionModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Extensions


struct SharePreviewSectionModel: Equatable, Sendable, Identifiable {

    /// nil = 날짜에 매이지 않는 할일 섹션
    let dayStart: TimeInterval?
    var dayHeaderText: String?
    var lines: [SharePreviewLineModel]

    var id: String { self.dayStart.map { "\($0)" } ?? "undated" }
}


// MARK: - SharePreviewSectionComposer

struct SharePreviewSectionComposer {

    let timeZone: TimeZone
    var now: Date = Date()

    private var calendar: Calendar {
        return Calendar(identifier: .gregorian) |> \.timeZone .~ self.timeZone
    }

    func sections(of lines: [SharePreviewLineModel]) -> [SharePreviewSectionModel] {
        let undatedLines = lines.filter { $0.dayStart == nil }
        let groups = Dictionary(grouping: lines.filter { $0.dayStart != nil }, by: { $0.dayStart! })
        let sortedDayStarts = groups.keys.sorted()
        let isMultiDay = sortedDayStarts.count > 1

        let undatedSection = undatedLines.isEmpty ? nil : SharePreviewSectionModel(
            dayStart: nil, dayHeaderText: nil, lines: undatedLines
        )
        let daySections = sortedDayStarts.map { dayStart in
            SharePreviewSectionModel(
                dayStart: dayStart,
                dayHeaderText: isMultiDay ? self.dayHeaderText(for: dayStart) : nil,
                lines: groups[dayStart] ?? []
            )
        }
        return [undatedSection].compactMap { $0 } + daySections
    }

    func rangeHeaderText(
        of sections: [SharePreviewSectionModel],
        in range: Range<TimeInterval>,
        kind: CalendarShareRangeKind
    ) -> String {
        let dayStarts = sections.compactMap { $0.dayStart }
        guard dayStarts.count > 1 else {
            let dayStart = dayStarts.first ?? range.lowerBound
            return self.formattedDate(dayStart, format: "date_form::yyyy_MM_dd_E_".localized())
        }
        switch kind {
        case .week: return self.weekHeaderText(for: range)
        case .day, .month: return self.formattedDate(range.lowerBound, format: "date_form.MMM_yyyy".localized())
        }
    }

    private func weekHeaderText(for range: Range<TimeInterval>) -> String {
        let nowTime = self.now.timeIntervalSince1970
        let calendar = self.calendar
        let shiftedByWeeks: (TimeInterval, Int) -> TimeInterval? = { time, weeks in
            calendar.date(byAdding: .day, value: weeks * 7, to: Date(timeIntervalSince1970: time))?
                .timeIntervalSince1970
        }
        if range.contains(nowTime) {
            return "share_preview::header::this_week".localized()
        }
        if let nextWeekEnd = shiftedByWeeks(range.upperBound, 1),
           (range.upperBound..<nextWeekEnd).contains(nowTime) {
            return "share_preview::header::last_week".localized()
        }
        if let previousWeekStart = shiftedByWeeks(range.lowerBound, -1),
           (previousWeekStart..<range.lowerBound).contains(nowTime) {
            return "share_preview::header::next_week".localized()
        }
        return self.weekOfMonthText(for: range.lowerBound)
    }

    // 주차는 그 주의 시작일이 속한 달 기준 — 달 1일이 포함된 주가 1주차다
    private func weekOfMonthText(for weekStartTime: TimeInterval) -> String {
        let monthText = self.formattedDate(weekStartTime, format: "date_form.MMM".localized())
        guard let ordinal = self.weekOrdinalInMonth(of: weekStartTime) else {
            return self.formattedDate(weekStartTime, format: "date_form.MMM_yyyy".localized())
        }
        return "share_preview::header::week_of_month".localized(with: monthText, ordinal)
    }

    private func weekOrdinalInMonth(of weekStartTime: TimeInterval) -> Int? {
        let calendar = self.calendar
        let weekStart = Date(timeIntervalSince1970: weekStartTime)
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: weekStart))
        else { return nil }
        let daysBackToWeekStart = (
            calendar.component(.weekday, from: monthStart) - calendar.component(.weekday, from: weekStart) + 7
        ) % 7
        guard let firstWeekStart = calendar.date(byAdding: .day, value: -daysBackToWeekStart, to: monthStart),
              let elapsedDays = calendar.dateComponents([.day], from: firstWeekStart, to: weekStart).day
        else { return nil }
        return elapsedDays / 7 + 1
    }

    private func dayHeaderText(for dayStart: TimeInterval) -> String {
        let dateText = self.formattedDate(dayStart, format: "date_form.MMM_dd_E".localized())
        return "\(Constant.dayHeaderMarker)\(dateText)"
    }

    private func formattedDate(_ time: TimeInterval, format: String) -> String {
        let formatter = DateFormatter() |> \.timeZone .~ self.timeZone
        formatter.dateFormat = format
        return formatter.string(from: Date(timeIntervalSince1970: time))
    }
}

private enum Constant {
    static let dayHeaderMarker: String = "▸ "
}
