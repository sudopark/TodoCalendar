//
//  WidgetStyleLicenseGuide.swift
//  WidgetScenes
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import Scenes


protocol WidgetStyleLicenseGuideRouting: Routing {

    func routeToRewardedAd(completion: @escaping @Sendable (RewardedAdResult) -> Void)
    func routeToPaywall()
}


final class WidgetStyleLicenseGuide: @unchecked Sendable {

    private let paidFeatureGateUsecase: any WidgetStylePaidFeatureGateUsecase
    weak var router: (any WidgetStyleLicenseGuideRouting)?

    init(paidFeatureGateUsecase: any WidgetStylePaidFeatureGateUsecase) {
        self.paidFeatureGateUsecase = paidFeatureGateUsecase
    }

    func show(then continuation: @escaping @Sendable () -> Void) {
        guard let licenseDays = self.paidFeatureGateUsecase.widgetStyleLicenseDays() else {
            self.notifyAdUnavailable()
            return
        }
        let form = ActionSheetForm()
            |> \.title .~ pure("widget.style.license::title".localized())
            |> \.message .~ pure("widget.style.license::message".localized(with: licenseDays))
            |> \.actions .~ [
                .init("widget.style.license::watchAd".localized()) { [weak self] in
                    self?.router?.routeToRewardedAd { [weak self] result in
                        self?.handleAdResult(result, then: continuation)
                    }
                },
                .init("widget.style.license::showPlans".localized()) { [weak self] in
                    self?.router?.routeToPaywall()
                },
                .init("common.cancel".localized(), style: .cancel)
            ]
        self.router?.showActionSheet(form)
    }

    private func handleAdResult(_ result: RewardedAdResult, then continuation: () -> Void) {
        switch self.paidFeatureGateUsecase.widgetStyleLicenseDecision(for: result) {
        case .grantLicenseAndContinue:
            self.paidFeatureGateUsecase.grantCustomWidgetStyleLicense(at: Date())
            WidgetCenter.shared.reloadAllTimelines()
            continuation()
        case .notifyAdUnavailable:
            self.notifyAdUnavailable()
        case .continueWithoutLicense, .cancel:
            break
        }
    }

    private func notifyAdUnavailable() {
        self.router?.showToast("widget.style.license::adUnavailable".localized())
    }
}
