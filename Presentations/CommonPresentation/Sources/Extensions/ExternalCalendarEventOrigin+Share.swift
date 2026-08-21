//
//  ExternalCalendarEventOrigin+Share.swift
//  CommonPresentation
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


// MARK: - GoogleCalendar.EventOrigin time <-> SelectedTime mapping

public extension GoogleCalendar.EventOrigin {

    func selectedTime(_ timeZone: TimeZone) -> SelectedTime? {
        let start = self.start?.supportEventTimeElemnt(timeZone.identifier)
        let end = self.end?.supportEventTimeElemnt(timeZone.identifier)
        switch (start, end) {
        case (.period(let st), .period(let et)):
            return SelectedTime(
                .period(st.timeIntervalSince1970..<et.timeIntervalSince1970), timeZone
            )
        case (.allDay(let st, let sz), .allDay(let et, _)):
            return SelectedTime(
                .allDay(
                    st.timeIntervalSince1970..<et.timeIntervalSince1970,
                    secondsFromGMT: TimeInterval(sz.secondsFromGMT())
                ),
                timeZone
            )
        default:
            return nil
        }
    }
}


// MARK: - 반복 규칙 공유 텍스트 — 상세 화면의 잠김·파싱실패 분기와 동일하게 판정

public extension GoogleCalendar.EventOrigin {

    private var rruleLines: [String] {
        self.recurrence?.filter { $0.hasPrefix("RRULE:") } ?? []
    }

    private func editableRepeating(_ timeZone: TimeZone) -> EventRepeating? {
        guard self.rruleLines.count == 1,
              let rruleLine = self.rruleLines.first,
              let startTime = self.selectedTime(timeZone)?.startDate.timeIntervalSince1970,
              let rrule = RRuleParser.parse(rruleLine)
        else { return nil }
        return rrule.asEventRepeating(startTime: startTime, timeZone: timeZone)
    }

    func shareRepeatText(_ timeZone: TimeZone) -> String? {
        guard self.rruleLines.isEmpty == false else { return nil }
        guard let editableRepeating = self.editableRepeating(timeZone) else {
            guard let rruleLine = self.rruleLines.first, let rrule = RRuleParser.parse(rruleLine) else {
                return self.rruleLines.first?.strippingRRulePrefix
            }
            return rrule.appendingEndOptionText(to: rrule.frequencyText(), timeZone)
        }
        let displayText = editableRepeating.repeatOptionDisplayText(timeZone)
        return displayText == R.String.EventDetail.Repeating.notRepeatingTitle ? nil : displayText
    }
}


public extension AppleCalendar.EventOrigin {

    private var rruleLines: [String] {
        self.recurrenceRules.filter { $0.hasPrefix("RRULE:") }
    }

    // EventKit 은 반복 종료 날짜를 UTC 하루 끝 instant 로 돌려준다 — 재앵커링 없이 그대로 쓰면 종료일이 하루 밀린다
    private func editableRepeating(_ timeZone: TimeZone) -> EventRepeating? {
        guard self.rruleLines.count == 1,
              let rruleLine = self.rruleLines.first,
              let rrule = RRuleParser.parse(rruleLine)?.reanchoringUTCDayEndUntil(to: timeZone)
        else { return nil }
        return rrule.asEventRepeating(startTime: self.eventTime.lowerBoundWithFixed, timeZone: timeZone)
    }

    func shareRepeatText(_ timeZone: TimeZone) -> String? {
        guard self.rruleLines.isEmpty == false else { return nil }
        guard let editableRepeating = self.editableRepeating(timeZone) else {
            guard let rruleLine = self.rruleLines.first,
                  let rrule = RRuleParser.parse(rruleLine)?.reanchoringUTCDayEndUntil(to: timeZone)
            else {
                return self.rruleLines.first?.strippingRRulePrefix
            }
            return rrule.appendingEndOptionText(to: rrule.frequencyText(), timeZone)
        }
        let displayText = editableRepeating.repeatOptionDisplayText(timeZone)
        return displayText == R.String.EventDetail.Repeating.notRepeatingTitle ? nil : displayText
    }
}


// MARK: - HTML description -> plain share text

private enum ShareTextConstant {
    // 구글 캘린더 설명에 실제로 쓰이는 태그만 화이트리스트. 각괄호 이메일(<user@x.com>)·URL(<https://...>) 오탐 방지 — 태그명 뒤 경계(공백/슬래시/닫힘)를 요구해 <abbr> 같은 미등재 태그 접두 매치도 차단한다.
    static let htmlTagPattern =
        "</?(?:br|b|i|u|p|div|span|a|ul|ol|li|strong|em|h[1-6]|table|tr|td|img|font)(?=[\\s/>])"
}

public extension String {

    var hasHTMLTag: Bool {
        self.range(
            of: ShareTextConstant.htmlTagPattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}

public extension Optional where Wrapped == String {

    var asPlainShareText: String? {
        guard let memo = self else { return nil }
        guard memo.hasHTMLTag else { return memo.emptyAsNil() }
        guard let attributed = memo.asHTMLAttributeText else { return memo.emptyAsNil() }
        return String(attributed.characters).emptyAsNil()
    }
}
