//
//  BillingScheduledChangeView.swift
//  CommonPresentation
//
//  Created by sudo.park on 8/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import Extensions


public struct BillingScheduledChangeView: View {

    @Environment(ViewAppearance.self) private var appearance
    private let change: BillingUserPlan.ScheduledChange

    public init(change: BillingUserPlan.ScheduledChange) {
        self.change = change
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Metric.Spacing.xxsmall) {
            Image(systemName: "info.circle")
            Text("aiAgent::usage::planChangeScheduled".localized(
                with: self.change.effectiveAt.text("date_form::MMM_d".localized()),
                self.change.planId.name
            ))
        }
        .font(self.appearance.fontSet.size(12).asFont)
        .foregroundStyle(self.appearance.colorSet.accentInfo.asColor)
    }
}
