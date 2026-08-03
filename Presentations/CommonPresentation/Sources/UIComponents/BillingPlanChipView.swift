//
//  BillingPlanChipView.swift
//  CommonPresentation
//
//  Created by sudo.park on 8/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain


// MARK: - BillingPlanId + 표시 이름

public extension BillingPlanId {

    var name: String {
        switch self {
        case .free:     return "billing::plan::free".localized()
        case .standard: return "billing::plan::standard".localized()
        case .lifetime: return "billing::plan::lifetime".localized()
        }
    }
}


// MARK: - BillingPlanChipView

// 플랜 표시 칩 — 사용량 게이지와 paywall 이 공유한다. 무료는 회색, 유료는 accentAI
public struct BillingPlanChipView: View {

    @Environment(ViewAppearance.self) private var appearance
    private let plan: BillingPlanId

    public init(plan: BillingPlanId) {
        self.plan = plan
    }

    public var body: some View {
        Text(self.plan.name)
            .font(self.appearance.fontSet.size(10, weight: .semibold).asFont)
            .foregroundStyle(
                self.plan == .free
                    ? self.appearance.colorSet.text2.asColor
                    : self.appearance.colorSet.primaryBtnText.asColor
            )
            .padding(.horizontal, spacing: .xsmall)
            .padding(.vertical, spacing: .xxsmall)
            .background(
                RoundedRectangle(cornerRadius: Metric.Radius.chip)
                    .fill(
                        self.plan == .free
                            ? self.appearance.colorSet.bg1.asColor
                            : self.appearance.colorSet.accentAI.asColor
                    )
            )
    }
}
