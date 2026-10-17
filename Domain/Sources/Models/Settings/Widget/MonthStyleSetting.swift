//
//  MonthStyleSetting.swift
//  Domain
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct MonthStyleSetting: WidgetStyleSetting {

    public var showMonthName: Bool
    public var showWeekDayHeader: Bool
    public var highlightToday: Bool
    public var showEventUnderline: Bool

    public static let initial = MonthStyleSetting(
        showMonthName: true,
        showWeekDayHeader: true,
        highlightToday: true,
        showEventUnderline: true
    )
}


// MARK: - 디코딩

extension MonthStyleSetting {

    /// 저장값에 없는 항목은 초기값으로 채운다 — 표시 항목이 늘어도 옛 저장값이 그대로 산다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let initial = Self.initial
        self.showMonthName = try container.decodeIfPresent(
            Bool.self, forKey: .showMonthName
        ) ?? initial.showMonthName
        self.showWeekDayHeader = try container.decodeIfPresent(
            Bool.self, forKey: .showWeekDayHeader
        ) ?? initial.showWeekDayHeader
        self.highlightToday = try container.decodeIfPresent(
            Bool.self, forKey: .highlightToday
        ) ?? initial.highlightToday
        self.showEventUnderline = try container.decodeIfPresent(
            Bool.self, forKey: .showEventUnderline
        ) ?? initial.showEventUnderline
    }
}
