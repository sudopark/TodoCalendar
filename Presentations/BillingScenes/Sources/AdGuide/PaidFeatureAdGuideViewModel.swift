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
    func useDefault()
    func handleSheetDismissed()

    // presenter
    var reason: AnyPublisher<PaidFeatureGateFailReason, Never> { get }
    var canUseDefault: AnyPublisher<Bool, Never> { get }
    var canShowPlans: AnyPublisher<Bool, Never> { get }
}


// MARK: - PaidFeatureAdGuideViewModelImple

final class PaidFeatureAdGuideViewModelImple: PaidFeatureAdGuideViewModel, @unchecked Sendable {

    private let failReason: PaidFeatureGateFailReason
    private let paidFeatureGateUsecase: any PaidFeatureGateUsecase
    private let accountUsecase: any AccountUsecase
    private let onFinished: @Sendable (Bool) -> Void
    private let onUseDefault: (@Sendable () -> Void)?
    private var hasChosenToFinish: Bool = false
    var router: (any PaidFeatureAdGuideRouting)?

    init(
        reason: PaidFeatureGateFailReason,
        paidFeatureGateUsecase: any PaidFeatureGateUsecase,
        accountUsecase: any AccountUsecase,
        onFinished: @escaping @Sendable (Bool) -> Void,
        onUseDefault: (@Sendable () -> Void)?
    ) {
        self.failReason = reason
        self.paidFeatureGateUsecase = paidFeatureGateUsecase
        self.accountUsecase = accountUsecase
        self.onFinished = onFinished
        self.onUseDefault = onUseDefault
    }
}


// MARK: - 시트 선택

extension PaidFeatureAdGuideViewModelImple {

    func watchAd() {
        guard self.hasChosenToFinish == false else { return }
        self.hasChosenToFinish = true
        self.router?.routeToRewardedAd { [weak self] result in
            self?.finishAfterAd(result)
        }
    }

    func showPlans() {
        guard self.hasChosenToFinish == false else { return }
        self.router?.routeToPaywall()
    }

    func close() {
        guard self.hasChosenToFinish == false else { return }
        self.router?.closeScene()
    }

    func useDefault() {
        guard self.hasChosenToFinish == false else { return }
        self.hasChosenToFinish = true
        self.router?.closeScene { [onUseDefault, onFinished] in
            onUseDefault?()
            onFinished(false)
        }
    }

    func handleSheetDismissed() {
        guard self.hasChosenToFinish == false else { return }
        self.onFinished(false)
    }

    private func finishAfterAd(_ result: RewardedAdResult) {
        switch (result, self.failReason.feature) {
        case (.rewarded, _), (.fallbackFullScreenShown, _):
            self.paidFeatureGateUsecase.grantLicense(for: self.failReason.feature, at: Date())
            self.closeScene(thenFinish: true)
        case (.unavailable, _):
            self.router?.showToast("paidFeature.adGuide::adUnavailable".localized())
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

    var canUseDefault: AnyPublisher<Bool, Never> {
        return Just(self.onUseDefault != nil).eraseToAnyPublisher()
    }

    var canShowPlans: AnyPublisher<Bool, Never> {
        return self.accountUsecase.currentAccountInfo
            .map { $0 != nil }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
