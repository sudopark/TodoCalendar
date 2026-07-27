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

                if let plan = self.usage.plan {
                    self.planChipView(plan)
                }
            }

            if let remaining = self.usage.topupRemaining, remaining > 0 {
                Text("aiAgent::usage::topupRemaining".localized(with: remaining.formatted()))
                    .font(self.appearance.fontSet.size(12).asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)
            }

            if let change = self.usage.scheduledPlanChange {
                self.scheduledChangeView(change)
            }
        }
    }
}


// MARK: - plan chip

private extension AIAgentUsageGaugeView {

    func planChipView(_ plan: AIAgentUsage.Plan) -> some View {
        Text(plan.name)
            .font(self.appearance.fontSet.size(10, weight: .semibold).asFont)
            .foregroundStyle(
                plan == .free
                    ? self.appearance.colorSet.text2.asColor
                    : self.appearance.colorSet.primaryBtnText.asColor
            )
            .padding(.horizontal, spacing: .xsmall)
            .padding(.vertical, spacing: .xxsmall)
            .background(
                RoundedRectangle(cornerRadius: Metric.Radius.chip)
                    .fill(
                        plan == .free
                            ? self.appearance.colorSet.bg1.asColor
                            : self.appearance.colorSet.accentAI.asColor
                    )
            )
    }

}

private extension AIAgentUsage.Plan {

    var name: String {
        switch self {
        case .free:     return "aiAgent::plan::free".localized()
        case .standard: return "aiAgent::plan::standard".localized()
        case .lifetime: return "aiAgent::plan::lifetime".localized()
        }
    }
}


// MARK: - scheduled plan change

private extension AIAgentUsageGaugeView {

    func scheduledChangeView(_ change: AIAgentUsage.ScheduledPlanChange) -> some View {
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
