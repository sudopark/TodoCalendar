//
//  WeekEventsStyleSetting.swift
//  SettingDomainInterface
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct WeekEventsStyleSetting: WidgetStyleSetting {

    public var showWeekDayHeader: Bool
    public var eventTextSize: Int

    public static let initial = WeekEventsStyleSetting(
        showWeekDayHeader: true,
        eventTextSize: Constant.eventTextSizeRange.lowerBound
    )

    public var eventTextSizeRange: ClosedRange<Int> {
        Constant.eventTextSizeRange
    }
}


private enum Constant {
    static let eventTextSizeRange: ClosedRange<Int> = 8...10
}


// MARK: - 디코딩

extension WeekEventsStyleSetting {

    /// 저장값에 없는 항목은 초기값으로 채운다 — 표시 항목이 늘어도 옛 저장값이 그대로 산다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let initial = Self.initial
        self.showWeekDayHeader = try container.decodeIfPresent(
            Bool.self, forKey: .showWeekDayHeader
        ) ?? initial.showWeekDayHeader
        let storedEventTextSize = try container.decodeIfPresent(
            Int.self, forKey: .eventTextSize
        ) ?? initial.eventTextSize
        self.eventTextSize = min(
            max(storedEventTextSize, initial.eventTextSizeRange.lowerBound),
            initial.eventTextSizeRange.upperBound
        )
    }
}
