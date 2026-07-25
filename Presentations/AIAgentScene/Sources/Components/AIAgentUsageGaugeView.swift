//
//  AIAgentUsageGaugeView.swift
//  AIAgentScene
//
//  Created by sudo.park on 7/25/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import CommonPresentation


// 사용량/일일 한도 미니 게이지 — 키보드 입력·커맨드 시트 공유 (#713)
struct AIAgentUsageGaugeView: View {

    @Environment(ViewAppearance.self) private var appearance

    private let usage: AIAgentUsage
    // 사용률 90% 이상은 경고 틴트 — 한도 임박 알림을 게이지가 겸한다
    private static let warnThreshold: Double = 0.9

    init(usage: AIAgentUsage) {
        self.usage = usage
    }

    private var isNearLimit: Bool { self.usage.usedRatio >= Self.warnThreshold }

    private var fillColor: Color {
        self.isNearLimit
            ? self.appearance.colorSet.accentWarn.asColor
            : self.appearance.colorSet.accentAI.asColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.xsmall) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(self.appearance.colorSet.bg1.asColor)
                    Capsule()
                        .fill(self.fillColor)
                        .frame(width: proxy.size.width * self.usage.usedRatio)
                }
            }
            .frame(height: 6)

            Text("aiAgent::usage".localized(
                with: self.usage.usedTokens.formatted(), self.usage.dailyLimit.formatted()
            ))
            .font(self.appearance.fontSet.size(12).asFont)
            .foregroundStyle(
                self.isNearLimit
                    ? self.appearance.colorSet.accentWarn.asColor
                    : self.appearance.colorSet.text2.asColor
            )
        }
    }
}
