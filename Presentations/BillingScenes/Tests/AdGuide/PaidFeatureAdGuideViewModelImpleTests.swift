//
//  PaidFeatureAdGuideViewModelImpleTests.swift
//  BillingScenesTests
//
//  Created by sudo.park on 10/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import Scenes
import Extensions
import TestDoubles

@testable import BillingScenes


private final class SpyAdGuideRouter: BaseSpyRouter, PaidFeatureAdGuideRouting, @unchecked Sendable {

    private let adResult: RewardedAdResult
    init(adResult: RewardedAdResult) {
        self.adResult = adResult
    }

    private(set) var didRouteToRewardedAd: Bool = false
    func routeToRewardedAd(_ completion: @escaping @Sendable (RewardedAdResult) -> Void) {
        self.didRouteToRewardedAd = true
        completion(self.adResult)
    }

    private(set) var didRouteToPaywall: Bool = false
    func routeToPaywall() {
        self.didRouteToPaywall = true
    }
}

private final class FinishedRecorder: @unchecked Sendable {
    var didFinishWith: [Bool] = []
    var wasSheetClosedAtFinish: [Bool] = []
}


@MainActor
final class PaidFeatureAdGuideViewModelImpleTests {

    private let gate = StubPaidFeatureGateUsecase()
    private let recorder = FinishedRecorder()
    private var router: SpyAdGuideRouter?

    private func makeViewModel(
        _ reason: PaidFeatureGateFailReason,
        adResult: RewardedAdResult = .rewarded
    ) -> PaidFeatureAdGuideViewModelImple {
        let router = SpyAdGuideRouter(adResult: adResult)
        self.router = router
        let viewModel = PaidFeatureAdGuideViewModelImple(
            reason: reason,
            paidFeatureGateUsecase: self.gate,
            onFinished: { [recorder, router] in
                recorder.didFinishWith.append($0)
                recorder.wasSheetClosedAtFinish.append(router.didClosed == true)
            }
        )
        viewModel.router = router
        return viewModel
    }
}


// MARK: - 광고 결과

extension PaidFeatureAdGuideViewModelImpleTests {

    @Test("광고 보상을 받거나 대체 전면광고를 보면 막힌 기능의 사용권을 기록하고 진행을 넘긴다", arguments: [
        (RewardedAdResult.rewarded, PaidFeature.customizeWidget),
        (.fallbackFullScreenShown, .customizeWidget),
        (.rewarded, .colorTheme(.appTheme(.tomato))),
        (.fallbackFullScreenShown, .colorTheme(.appTheme(.tomato)))
    ])
    func watchAd_whenRewarded_grantsLicenseOfFeatureAndProceeds(
        _ result: RewardedAdResult, _ feature: PaidFeature
    ) {
        // given
        let viewModel = self.makeViewModel(.init(feature: feature, licenseDays: 7), adResult: result)

        // when
        viewModel.watchAd()

        // then
        #expect(self.recorder.didFinishWith == [true])
        #expect(self.recorder.wasSheetClosedAtFinish == [true])
        #expect(self.gate.didGrantLicenseWith?.feature == feature)
    }

    @Test("컬러 테마는 광고가 없으면 사용권 없이 진행을 넘긴다")
    func watchAd_whenColorThemeAdUnavailable_proceedsWithoutLicense() {
        // given
        let viewModel = self.makeViewModel(
            .init(feature: .colorTheme(.appTheme(.tomato)), licenseDays: 7), adResult: .unavailable
        )

        // when
        viewModel.watchAd()

        // then
        #expect(self.recorder.didFinishWith == [true])
        #expect(self.gate.didGrantLicenseWith == nil)
        #expect(self.router?.didShowToastWithMessage == nil)
    }

    @Test("위젯 꾸미기는 광고가 없으면 광고 없음 토스트를 띄우고 진행하지 않는다")
    func watchAd_whenWidgetAdUnavailable_showsToastWithoutProceed() {
        // given
        let viewModel = self.makeViewModel(
            .init(feature: .customizeWidget, licenseDays: 7), adResult: .unavailable
        )

        // when
        viewModel.watchAd()

        // then
        #expect(self.recorder.didFinishWith == [false])
        #expect(self.recorder.wasSheetClosedAtFinish == [true])
        #expect(self.gate.didGrantLicenseWith == nil)
        #expect(self.router?.didShowToastWithMessage == "widget.style.license::adUnavailable".localized())
    }

    @Test("보상 전에 광고를 닫으면 기록 없이 진행하지 않는다")
    func watchAd_whenDismissedBeforeReward_finishesWithoutProceed() {
        // given
        let viewModel = self.makeViewModel(
            .init(feature: .customizeWidget, licenseDays: 7), adResult: .dismissedBeforeReward
        )

        // when
        viewModel.watchAd()

        // then
        #expect(self.recorder.didFinishWith == [false])
        #expect(self.gate.didGrantLicenseWith == nil)
    }
}


// MARK: - 플랜 보기·닫기

extension PaidFeatureAdGuideViewModelImpleTests {

    @Test("플랜 보기를 고르면 paywall 로 가고, 시트가 닫히면 진행 안 함을 넘긴다")
    func showPlans_routesToPaywallAndFinishesWithoutProceedWhenSheetDismissed() {
        // given
        let viewModel = self.makeViewModel(.init(feature: .customizeWidget, licenseDays: 7))

        // when
        viewModel.showPlans()
        let finishedBeforeDismissed = self.recorder.didFinishWith
        viewModel.handleSheetDismissed()

        // then
        #expect(finishedBeforeDismissed == [])
        #expect(self.recorder.didFinishWith == [false])
        #expect(self.router?.didRouteToPaywall == true)
        #expect(self.router?.didRouteToRewardedAd == false)
    }

    @Test("닫기를 고르면 시트를 닫고, 시트가 닫히면 진행 안 함을 넘긴다")
    func close_closesSheetAndFinishesWithoutProceedWhenSheetDismissed() {
        // given
        let viewModel = self.makeViewModel(.init(feature: .customizeWidget, licenseDays: 7))

        // when
        viewModel.close()
        let finishedBeforeDismissed = self.recorder.didFinishWith
        viewModel.handleSheetDismissed()

        // then
        #expect(finishedBeforeDismissed == [])
        #expect(self.recorder.didFinishWith == [false])
        #expect(self.router?.didClosed == true)
    }

    @Test("광고를 고른 뒤 시트가 닫혔다는 알림이 와도 결과는 광고 결과 하나만 넘긴다")
    func watchAd_thenSheetDismissed_finishesOnlyWithAdResult() {
        // given
        let viewModel = self.makeViewModel(.init(feature: .customizeWidget, licenseDays: 7))

        // when
        viewModel.watchAd()
        viewModel.handleSheetDismissed()

        // then
        #expect(self.recorder.didFinishWith == [true])
    }
}
