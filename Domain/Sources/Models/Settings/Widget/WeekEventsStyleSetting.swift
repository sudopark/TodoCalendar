//
//  WeekEventsStyleSetting.swift
//  Domain
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct WeekEventsStyleSetting: WidgetStyleSetting {

    public var showWeekDayHeader: Bool

    public static let initial = WeekEventsStyleSetting(
        showWeekDayHeader: true
    )
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
    }
}
