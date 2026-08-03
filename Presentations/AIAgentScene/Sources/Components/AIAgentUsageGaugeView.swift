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
// 플랜 칩·top-up 잔량·하향 예약 안내는 값이 있을 때만 붙는다 (#720)
struct AIAgentUsageGaugeView: View {

    @Environment(ViewAppearance.self) private var appearance

    private let usage: AIAgentUsage
    // 플랜 정보 정본은 billingUserPlan 키 — usage 에서 흡수하지 않고 별도로 받는다 (#739)
    private let userPlan: BillingUserPlan?
    // 사용률 90% 이상은 경고 틴트 — 한도 임박 알림을 게이지가 겸한다
    private static let warnThreshold: Double = 0.9

    init(usage: AIAgentUsage, userPlan: BillingUserPlan?) {
        self.usage = usage
        self.userPlan = userPlan
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

            HStack(spacing: Metric.Spacing.small) {
                Text("aiAgent::usage".localized(
                    with: self.usage.usedCredits.formatted(), self.usage.dailyLimit.formatted()
                ))
                .font(self.appearance.fontSet.size(12).asFont)
                .foregroundStyle(
                    self.isNearLimit
                        ? self.appearance.colorSet.accentWarn.asColor
                        : self.appearance.colorSet.text2.asColor
                )

                Spacer()

                if let plan = self.userPlan?.planId {
                    BillingPlanChipView(plan: plan)
                }
            }

            if let remaining = self.userPlan?.topupRemaining, remaining > 0 {
                Text("aiAgent::usage::topupRemaining".localized(with: remaining.formatted()))
                    .font(self.appearance.fontSet.size(12).asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)
            }

            if let change = self.userPlan?.scheduledChange {
                self.scheduledChangeView(change)
            }
        }
    }
}


// MARK: - scheduled plan change

private extension AIAgentUsageGaugeView {

    func scheduledChangeView(_ change: BillingUserPlan.ScheduledChange) -> some View {
        HStack(alignment: .top, spacing: Metric.Spacing.xxsmall) {
            Image(systemName: "info.circle")
            Text("aiAgent::usage::planChangeScheduled".localized(
                with: change.effectiveAt.text("date_form::MMM_d".localized()), change.planId.name
            ))
        }
        .font(self.appearance.fontSet.size(12).asFont)
        .foregroundStyle(self.appearance.colorSet.accentInfo.asColor)
    }
}
