//
//  TodayStyleSetting.swift
//  Domain
//
//  Created by sudo.park on 9/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct TodayStyleSetting: WidgetStyleSetting {

    public var showHolidayName: Bool
    public var showTimeZone: Bool
    public var showMonthYear: Bool
    public var showTotalCount: Bool
    public var showTodoCount: Bool
    public var showScheduleCount: Bool

    public static let initial = TodayStyleSetting(
        showHolidayName: true,
        showTimeZone: true,
        showMonthYear: true,
        showTotalCount: true,
        showTodoCount: true,
        showScheduleCount: true
    )
}


// MARK: - 디코딩

extension TodayStyleSetting {

    /// 저장값에 없는 항목은 초기값으로 채운다 — 표시 항목이 늘어도 옛 저장값이 그대로 산다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let initial = Self.initial
        self.showHolidayName = try container.decodeIfPresent(
            Bool.self, forKey: .showHolidayName
        ) ?? initial.showHolidayName
        self.showTimeZone = try container.decodeIfPresent(
            Bool.self, forKey: .showTimeZone
        ) ?? initial.showTimeZone
        self.showMonthYear = try container.decodeIfPresent(
            Bool.self, forKey: .showMonthYear
        ) ?? initial.showMonthYear
        self.showTotalCount = try container.decodeIfPresent(
            Bool.self, forKey: .showTotalCount
        ) ?? initial.showTotalCount
        self.showTodoCount = try container.decodeIfPresent(
            Bool.self, forKey: .showTodoCount
        ) ?? initial.showTodoCount
        self.showScheduleCount = try container.decodeIfPresent(
            Bool.self, forKey: .showScheduleCount
        ) ?? initial.showScheduleCount
    }
}
