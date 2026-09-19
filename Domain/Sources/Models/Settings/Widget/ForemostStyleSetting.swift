//
//  ForemostStyleSetting.swift
//  Domain
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct ForemostStyleSetting: WidgetStyleSetting {

    public var showTypeLabel: Bool

    public static let initial = ForemostStyleSetting(
        showTypeLabel: true
    )
}


// MARK: - 디코딩

extension ForemostStyleSetting {

    /// 저장값에 없는 항목은 초기값으로 채운다 — 표시 항목이 늘어도 옛 저장값이 그대로 산다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let initial = Self.initial
        self.showTypeLabel = try container.decodeIfPresent(
            Bool.self, forKey: .showTypeLabel
        ) ?? initial.showTypeLabel
    }
}
