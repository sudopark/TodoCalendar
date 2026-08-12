//
//  AIAgentUsageGaugeView.swift
//  AIAgentScene
//
//  Created by sudo.park on 7/25/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import Extensions
import CommonPresentation


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

            if self.usage.isLimitExceeded, let resetsAt = self.usage.resetsAt {
                self.resetCountdownView(resetsAt)
            }

            if let remaining = self.userPlan?.topupRemaining, remaining > 0 {
                Text("aiAgent::usage::topupRemaining".localized(with: remaining.formatted()))
                    .font(self.appearance.fontSet.size(12).asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)
            }

            if let change = self.userPlan?.scheduledChange {
                BillingScheduledChangeView(change: change)
            }
        }
    }
}


// MARK: - 한도 리셋 카운트다운

extension AIAgentUsageGaugeView {

    // 매 초 도는 대신 표기가 바뀌는 시각에만 다시 그린다
    struct ResetSchedule: TimelineSchedule {

        private let resetsAt: Date

        init(resetsAt: Date) {
            self.resetsAt = resetsAt
        }

        func entries(from startDate: Date, mode: Mode) -> AnySequence<Date> {
            let resetsAt = self.resetsAt
            return AnySequence(
                sequence(first: startDate) { $0.nextCountdownTick(until: resetsAt) }
            )
        }
    }
}


private extension AIAgentUsageGaugeView {

    func resetCountdownView(_ resetsAt: Date) -> some View {
        TimelineView(ResetSchedule(resetsAt: resetsAt)) { context in
            // 디스플레이 링크 없는 정적 렌더(스냅샷 캡처)에선 TimelineView 가 미래 스케줄 시각을
            // context.date 로 줄 수 있어 벽시계로 클램프 — 온스크린에선 현재를 앞서지 않아 no-op
            let now = min(context.date, Date())
            if let remainingText = resetsAt.timeIntervalSince(now).countdownText() {
                HStack(alignment: .top, spacing: Metric.Spacing.xxsmall) {
                    Image(systemName: "hourglass")
                    Text("aiAgent::usage::resetsIn".localized(with: remainingText))
                }
                .font(self.appearance.fontSet.size(12).asFont)
                .foregroundStyle(self.appearance.colorSet.accentWarn.asColor)
            }
        }
    }
}
