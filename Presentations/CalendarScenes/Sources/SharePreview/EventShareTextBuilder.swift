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
        kind: CalendarShareRangeKind,
        includeTagName: Bool
    ) -> String {
        let visibleLines = lines.filter { !$0.isExcluded }
        guard !visibleLines.isEmpty else { return "" }

        let composer = SharePreviewSectionComposer(timeZone: self.timeZone)
        let sections = composer.sections(of: visibleLines)
        let header = "\(Constant.calendarEmoji)\(composer.rangeHeaderText(of: sections, in: range, kind: kind))"
        // 날짜 헤더가 없으면 섹션 경계가 드러나지 않아 빈 줄 없이 한 덩어리로 잇는다
        let sectionSeparator = sections.contains { $0.dayHeaderText != nil } ? "\n\n" : "\n"
        let body = sections
            .map { self.renderSection($0, includeTagName: includeTagName) }
            .joined(separator: sectionSeparator)

        return "\(header)\n\n\(body)"
    }

    private func renderSection(
        _ section: SharePreviewSectionModel,
        includeTagName: Bool
    ) -> String {
        let bullets = section.lines
            .map { self.bulletLine($0, includeTagName: includeTagName) }
            .joined(separator: "\n")
        guard let dayHeaderText = section.dayHeaderText else { return bullets }
        return "\(dayHeaderText)\n\(bullets)"
    }

    private func bulletLine(_ line: SharePreviewLineModel, includeTagName: Bool) -> String {
        let todoPrefix = line.isTodo ? "\(R.String.calendarEventTimeTodo) " : ""
        let timePrefix = line.timeText.map { "\($0) " } ?? ""
        let tagSuffix = (includeTagName ? line.tagName : nil).map { "\(Constant.tagSeparator)\($0)" } ?? ""
        return "\(Constant.bullet)\(todoPrefix)\(timePrefix)\(line.name)\(tagSuffix)"
    }

}

private enum Constant {
    static let calendarEmoji: String = "📅 "
    static let bullet: String = "• "
    static let tagSeparator: String = " · "
}
