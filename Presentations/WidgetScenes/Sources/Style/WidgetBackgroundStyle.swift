//
//  WidgetBackgroundStyle.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import CommonPresentation


/// 해석만 여기서 하고 적용은 각자 한다 — 확장은 `.containerBackground(for: .widget)`, 갤러리는 미리보기 프레임.
public struct WidgetBackgroundStyle {

    private let background: WidgetAppearanceSettings.Background

    public init(_ background: WidgetAppearanceSettings.Background) {
        self.background = background
    }

    public var shape: AnyShapeStyle {
        switch self.background {
        case .system:
            return AnyShapeStyle(.background)

        case .custom(let hex):
            guard let color = UIColor.from(hex: hex)
            else {
                return AnyShapeStyle(.background)
            }
            let colors: any ColorSet = color.isLight
                ? DefaultLightColorSet() : DefaultDarkColorSet()
            return AnyShapeStyle(
                color.asColor.gradient.shadow(
                    .drop(
                        color: colors.text0.withAlphaComponent(0.4).asColor,
                        radius: 10
                    )
                )
            )
        }
    }
}
