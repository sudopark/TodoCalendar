//
//  AICommandWidgetViews.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import Extensions
import CommonPresentation


/// 잠금화면 배경(`AccessoryWidgetBackground`)과 accent 처리는 WidgetKit 타입이라 확장의 엔트리 뷰가 씌운다.
public struct AICommandCircularView: View {

    public init() { }

    public var body: some View {
        Image("custom.calendar.badge.sparkles", bundle: .module)
            .font(.system(size: 20, weight: .semibold))
    }
}


public struct AICommandSmallView: View {

    @Environment(\.colorScheme) private var colorScheme
    private var colorSet: any ColorSet {
        return self.setting.background.colorSet(colorScheme == .light)
    }

    private let setting: WidgetAppearanceSettings

    public init(setting: WidgetAppearanceSettings) {
        self.setting = setting
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image("custom.calendar.badge.sparkles", bundle: .module)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(colorSet.accentAI.asColor)
            Spacer()
            Text("widget.aiCommand::title".localized())
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colorSet.text0.asColor)
            Text("widget.aiCommand::explain".localized())
                .font(.system(size: 11))
                .foregroundStyle(colorSet.text1.asColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
