//
//  EventAndForemostStyleSetting.swift
//  Domain
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics


public struct EventAndForemostStyleSetting: WidgetStyleSetting {

    public var foremost: ForemostStyleSetting

    public static let initial = EventAndForemostStyleSetting(
        foremost: .initial
    )
}


// MARK: - 디코딩

extension EventAndForemostStyleSetting {

    /// 저장값에 없는 절반은 초기값으로 채워 옛 저장값이 그대로 산다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let initial = Self.initial
        self.foremost = try container.decodeIfPresent(
            ForemostStyleSetting.self, forKey: .foremost
        ) ?? initial.foremost
    }
}


// MARK: - 절반 교체

extension EventAndForemostStyleSetting {

    public func replacingPart(_ part: any WidgetStyleSetting) -> Self {
        switch part {
        case let foremost as ForemostStyleSetting:
            return self |> \.foremost .~ foremost
        default:
            return self
        }
    }
}
