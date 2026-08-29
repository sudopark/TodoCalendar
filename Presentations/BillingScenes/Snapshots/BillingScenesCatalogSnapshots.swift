//
//  BillingScenesCatalogSnapshots.swift
//  BillingScenes
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import Extensions
import CommonPresentation
import SnapshotTestHelpKit

@testable import BillingScenes


final class BillingScenesCatalogSnapshots: XCTestCase {

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#D6236A", default: "#088CDA")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        return ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
    }

    @MainActor
    func test_plans() {
        captureSnapshotPair(
            named: "plans", layout: .fullScreen, snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            var container = PaywallContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandlers: PaywallViewEventHandler()
            )
            container.stateBinding = { state in
                state.currentPlan = .free
                state.currentPlanDescription = "billing::paywall::current::description".localized(with: "20")
                state.catalogState = .loaded([])
                state.screenState = .ready(state.catalogState)
                state.cellModels = [
                    PaywallPlanCellModel(
                        planId: .standard,
                        name: BillingPlanId.standard.name,
                        priceText: "$4.99",
                        periodText: "billing::paywall::period::monthly".localized(),
                        metricText: "billing::paywall::metric::dailyCredits".localized(with: "200"),
                        isOwned: false, isCovered: false, isRecommended: true
                    ),
                    PaywallPlanCellModel(
                        planId: .lifetime,
                        name: BillingPlanId.lifetime.name,
                        priceText: "$49.99",
                        periodText: nil,
                        metricText: "billing::paywall::metric::dailyCredits".localized(with: "500"),
                        isOwned: false, isCovered: false, isRecommended: false
                    )
                ]
                state.selectedPlanId = .standard
                state.selectedPlanDetail = PaywallPlanDetailModel(
                    sectionTitle: "billing::paywall::features::title".localized(with: BillingPlanId.standard.name),
                    features: [
                        "billing::paywall::feature::dailyCredits".localized(with: "200"),
                        "billing::paywall::feature::topup".localized()
                    ],
                    disclosure: "billing::paywall::disclosure::subscription".localized(),
                    ctaTitle: "billing::paywall::cta::subscribe".localized(with: BillingPlanId.standard.name)
                )
                state.isPurchasing = false
            }
            return container
        }
    }
}
