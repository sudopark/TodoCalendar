//
//  DDayWidgetViewModel.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


// MARK: - DDayWidgetViewModel

public struct DDayWidgetViewModel: Sendable {

    private enum Constant {
        /// 갤러리 샘플의 기준 시각 — 현재 시각을 쓰면 미리보기 스냅샷이 촬영일마다 밀린다.
        static let sampleBaseDate: TimeInterval = 1710374400
        static let sampleRemainSeconds: TimeInterval = 3600 * 24 * 14
    }

    public let eventTitle: String
    public let ddayText: String
    public let dateText: String
    public let timeText: String
    public let repeatText: String
    public var refreshAfter: Date?
    public var link: URL?
    public var widgetSetting: WidgetAppearanceSettings = .init()

    public init(
        eventTitle: String,
        ddayText: String,
        dateText: String,
        timeText: String,
        repeatText: String
    ) {
        self.eventTitle = eventTitle
        self.ddayText = ddayText
        self.dateText = dateText
        self.timeText = timeText
        self.repeatText = repeatText
    }

    public var isRepeating: Bool {
        return self.repeatText.isEmpty == false
    }

    /// 잠금화면 inline 한 줄. D-n을 앞에 두는 이유 — inline은 폭이 좁아 뒤에서부터 잘리는데,
    /// 제목이 길 때 남은 일수가 사라지면 이 위젯을 둘 이유가 없어진다.
    public var lockScreenInlineText: String {
        return [self.ddayText, self.eventTitle].joinedNonEmpty(separator: " · ")
    }

    public static var sample: Self {
        return .init(
            eventTitle: "widget.dday.sample::title".localized(),
            ddayText: "D-14",
            dateText: EventTime.at(Constant.sampleBaseDate + Constant.sampleRemainSeconds)
                .ddayDateText(in: .current),
            timeText: "",
            repeatText: ""
        )
    }

    public static func noTarget() -> Self {
        return .init(
            eventTitle: "widget.dday::noTarget".localized(),
            ddayText: "–",
            dateText: "",
            timeText: "",
            repeatText: ""
        )
    }
}


// MARK: - D-day 대상 시각 표기

extension EventTime {

    /// "2027년 3월 15일 (월)" 계열 — 로케일 템플릿.
    public func ddayDateText(in timeZone: TimeZone) -> String {
        return self.ddayText(in: timeZone, template: "yMMMdEEE")
    }

    /// "오전 7:00". 종일 일정은 시각이 의미 없어 빈 문자열.
    public func ddayTimeText(in timeZone: TimeZone) -> String {
        guard case .allDay = self else {
            return self.ddayText(in: timeZone, template: "jm")
        }
        return ""
    }

    private func ddayText(in timeZone: TimeZone, template: String) -> String {
        let date = Date(
            timeIntervalSince1970: self.rangeWithShifttingifNeed(on: timeZone).lowerBound
        )
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
