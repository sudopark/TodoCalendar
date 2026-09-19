//
//  DoubleMonthStyleSetting.swift
//  Domain
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics


public struct DoubleMonthStyleSetting: WidgetStyleSetting {

    public var month: MonthStyleSetting

    public static let initial = DoubleMonthStyleSetting(
        month: .initial
    )
}


// MARK: - 디코딩

extension DoubleMonthStyleSetting {

    /// 저장값에 없는 절반은 초기값으로 채워 옛 저장값이 그대로 산다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let initial = Self.initial
        self.month = try container.decodeIfPresent(
            MonthStyleSetting.self, forKey: .month
        ) ?? initial.month
    }
}


// MARK: - 절반 교체

extension DoubleMonthStyleSetting {

    public func replacingPart(_ part: any WidgetStyleSetting) -> Self {
        switch part {
        case let month as MonthStyleSetting:
            return self |> \.month .~ month
        default:
            return self
        }
    }
}
