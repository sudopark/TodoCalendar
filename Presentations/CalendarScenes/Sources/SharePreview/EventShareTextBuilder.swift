//
//  EventShareTextBuilder.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Extensions


struct EventShareTextBuilder {

    let timeZone: TimeZone

    func build(
        _ lines: [SharePreviewLineModel],
        in range: Range<TimeInterval>,
        includeTagName: Bool
    ) -> String {
        let visibleLines = lines.filter { !$0.isExcluded }
        guard !visibleLines.isEmpty else { return "" }

        let groups = Dictionary(grouping: visibleLines, by: \.dayStart)
        let sortedDayStarts = groups.keys.sorted()

        let headerDateText = sortedDayStarts.count == 1
            ? self.dateHeaderText(for: sortedDayStarts[0])
            : self.rangeHeaderText(for: range.lowerBound)
        let header = "\(Constant.calendarEmoji)\(headerDateText)"

        let body = sortedDayStarts.count == 1
            ? self.renderSingleDayBody(groups[sortedDayStarts[0]] ?? [], includeTagName: includeTagName)
            : self.renderMultiDayBody(sortedDayStarts, groups: groups, includeTagName: includeTagName)

        return "\(header)\n\n\(body)"
    }

    private func renderSingleDayBody(
        _ lines: [SharePreviewLineModel],
        includeTagName: Bool
    ) -> String {
        return lines
            .map { self.bulletLine($0, includeTagName: includeTagName) }
            .joined(separator: "\n")
    }

    private func renderMultiDayBody(
        _ sortedDayStarts: [TimeInterval],
        groups: [TimeInterval: [SharePreviewLineModel]],
        includeTagName: Bool
    ) -> String {
        return sortedDayStarts
            .map { dayStart -> String in
                let groupLines = groups[dayStart] ?? []
                let groupHeader = "\(Constant.groupMarker)\(self.groupHeaderText(for: dayStart))"
                let bullets = self.renderSingleDayBody(groupLines, includeTagName: includeTagName)
                return "\(groupHeader)\n\(bullets)"
            }
            .joined(separator: "\n\n")
    }

    private func bulletLine(_ line: SharePreviewLineModel, includeTagName: Bool) -> String {
        let todoPrefix = line.isTodo ? "\(R.String.calendarEventTimeTodo) " : ""
        let timePrefix = line.timeText.map { "\($0) " } ?? ""
        let tagSuffix = (includeTagName ? line.tagName : nil).map { "\(Constant.tagSeparator)\($0)" } ?? ""
        return "\(Constant.bullet)\(todoPrefix)\(timePrefix)\(line.name)\(tagSuffix)"
    }

    private func dateHeaderText(for dayStart: TimeInterval) -> String {
        return self.formattedDate(dayStart, format: "date_form::yyyy_MM_dd_E_".localized())
    }

    private func groupHeaderText(for dayStart: TimeInterval) -> String {
        return self.formattedDate(dayStart, format: "date_form.MMM_dd_E".localized())
    }

    private func rangeHeaderText(for time: TimeInterval) -> String {
        return self.formattedDate(time, format: "date_form.MMM_yyyy".localized())
    }

    private func formattedDate(_ time: TimeInterval, format: String) -> String {
        let formatter = DateFormatter() |> \.timeZone .~ self.timeZone
        formatter.dateFormat = format
        return formatter.string(from: Date(timeIntervalSince1970: time))
    }
}

private enum Constant {
    static let calendarEmoji: String = "📅 "
    static let groupMarker: String = "▸ "
    static let bullet: String = "• "
    static let tagSeparator: String = " · "
}
