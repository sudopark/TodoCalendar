//
//  PaidFeatureAdGuideViewModel.swift
//  BillingScenes
//
//  Created by sudo.park on 10/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions


// MARK: - PaidFeatureAdGuideViewModel

protocol PaidFeatureAdGuideViewModel: AnyObject, Sendable {

    // interactor
    func watchAd()
    func showPlans()
    func close()
    func handleSheetDismissed()

    // presenter
    var reason: AnyPublisher<PaidFeatureGateFailReason, Never> { get }
}


// MARK: - PaidFeatureAdGuideViewModelImple

final class PaidFeatureAdGuideViewModelImple: PaidFeatureAdGuideViewModel, @unchecked Sendable {

    private let failReason: PaidFeatureGateFailReason
    private let paidFeatureGateUsecase: any PaidFeatureGateUsecase
    private let onFinished: @Sendable (Bool) -> Void
    private var isWatchingAd: Bool = false
    var router: (any PaidFeatureAdGuideRouting)?

    init(
        reason: PaidFeatureGateFailReason,
        paidFeatureGateUsecase: any PaidFeatureGateUsecase,
        onFinished: @escaping @Sendable (Bool) -> Void
    ) {
        self.failReason = reason
        self.paidFeatureGateUsecase = paidFeatureGateUsecase
        self.onFinished = onFinished
    }
}


// MARK: - 시트 선택

extension PaidFeatureAdGuideViewModelImple {

    func watchAd() {
        guard self.isWatchingAd == false else { return }
        self.isWatchingAd = true
        self.router?.routeToRewardedAd { [weak self] result in
            self?.finishAfterAd(result)
        }
    }

    func showPlans() {
        guard self.isWatchingAd == false else { return }
        self.router?.routeToPaywall()
    }

    func close() {
        guard self.isWatchingAd == false else { return }
        self.router?.closeScene()
    }

    func handleSheetDismissed() {
        guard self.isWatchingAd == false else { return }
        self.onFinished(false)
    }

    private func finishAfterAd(_ result: RewardedAdResult) {
        switch (result, self.failReason.feature) {
        case (.rewarded, _), (.fallbackFullScreenShown, _):
            self.paidFeatureGateUsecase.grantLicense(for: self.failReason.feature, at: Date())
            self.closeScene(thenFinish: true)
        case (.unavailable, .colorTheme):
            self.closeScene(thenFinish: true)
        case (.unavailable, .customizeWidget):
            self.router?.showToast("widget.style.license::adUnavailable".localized())
            self.closeScene(thenFinish: false)
        case (.dismissedBeforeReward, _):
            self.closeScene(thenFinish: false)
        }
    }

    // 진행 결과를 받은 화면이 곧바로 다음 화면을 띄울 수 있어, 시트가 다 닫힌 뒤에 넘긴다
    private func closeScene(thenFinish shouldProceed: Bool) {
        self.router?.closeScene { [onFinished] in onFinished(shouldProceed) }
    }
}


// MARK: - 출력

extension PaidFeatureAdGuideViewModelImple {

    var reason: AnyPublisher<PaidFeatureGateFailReason, Never> {
        return Just(self.failReason).eraseToAnyPublisher()
    }
}
