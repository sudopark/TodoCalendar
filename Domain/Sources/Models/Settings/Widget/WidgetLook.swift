//
//  WidgetLook.swift
//  Domain
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


/// 전역 위젯 설정과 이 인스턴스가 고른 스타일을 한 벌로 묶는다 — 렌더로 가는 해석은 여기서만 일어난다.
public struct WidgetLook: Sendable {

    public let globalSetting: WidgetAppearanceSettings
    public let appliedStyle: WidgetStyle?

    public init(
        globalSetting: WidgetAppearanceSettings,
        appliedStyle: WidgetStyle? = nil
    ) {
        self.globalSetting = globalSetting
        self.appliedStyle = appliedStyle
    }
}


// MARK: - 해석

extension WidgetLook {

    /// 스타일이 색을 안 걸었으면 그 스타일이 전역을 따르는 것이다 — 변형 기본의 색을 빌려오지 않는다.
    public var background: WidgetAppearanceSettings.Background {
        return self.appliedStyle?.background ?? self.globalSetting.background
    }

    public func setting<S: WidgetStyleSetting>() -> S {
        return self.appliedStyle?.setting as? S ?? .initial
    }
}
