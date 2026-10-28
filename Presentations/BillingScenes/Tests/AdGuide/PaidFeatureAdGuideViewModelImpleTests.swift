//
//  PaidFeatureAdGuideViewModelImpleTests.swift
//  BillingScenesTests
//
//  Created by sudo.park on 10/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Combine
import Domain
import Scenes
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import BillingScenes


private final class SpyAdGuideRouter: BaseSpyRouter, PaidFeatureAdGuideRouting, @unchecked Sendable {

    private let adResult: RewardedAdResult
    init(adResult: RewardedAdResult) {
        self.adResult = adResult
    }

    private(set) var didRouteToRewardedAd: Bool = false
    var onRouteToRewardedAd: (() -> Void)?
    func routeToRewardedAd(_ completion: @escaping @Sendable (RewardedAdResult) -> Void) {
        self.didRouteToRewardedAd = true
        self.onRouteToRewardedAd?()
        completion(self.adResult)
    }

    private(set) var didRouteToPaywall: Bool = false
    func routeToPaywall() {
        self.didRouteToPaywall = true
    }
}

private enum AdGuideCallback: Equatable {
    case useDefault(wasSheetClosed: Bool)
    case finished(Bool)
}

private final class FinishedRecorder: @unchecked Sendable {
    var didFinishWith: [Bool] = []
    var wasSheetClosedAtFinish: [Bool] = []
    var callbacks: [AdGuideCallback] = []
}


@MainActor
final class PaidFeatureAdGuideViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()
    private let gate = StubPaidFeatureGateUsecase()
    private let recorder = FinishedRecorder()
    private var router: SpyAdGuideRouter?

    private func makeViewModel(
        _ reason: PaidFeatureGateFailReason,
        adResult: RewardedAdResult = .rewarded,
        withUseDefault: Bool = false,
        isSignedIn: Bool = true
    ) -> PaidFeatureAdGuideViewModelImple {
        let router = SpyAdGuideRouter(adResult: adResult)
        self.router = router
        let recorder = self.recorder
        let recordUseDefault: @Sendable () -> Void = { [recorder, router] in
            recorder.callbacks.append(AdGuideCallback.useDefault(wasSheetClosed: router.didClosed == true))
        }
        let viewModel = PaidFeatureAdGuideViewModelImple(
            reason: reason,
            paidFeatureGateUsecase: self.gate,
            accountUsecase: StubAccountUsecase(isSignedIn ? AccountInfo("uid") : nil),
            onFinished: { [recorder, router] in
                recorder.didFinishWith.append($0)
                recorder.wasSheetClosedAtFinish.append(router.didClosed == true)
                recorder.callbacks.append(.finished($0))
            },
            onUseDefault: withUseDefault ? recordUseDefault : nil
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
        (.rewarded, .colorTheme(isCustom: true)),
        (.fallbackFullScreenShown, .colorTheme(isCustom: true))
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

    @Test("광고가 없으면 기능에 상관없이 광고 없음 토스트를 띄우고 진행하지 않는다", arguments: [
        PaidFeature.customizeWidget,
        .colorTheme(isCustom: true)
    ])
    func watchAd_whenAdUnavailable_showsToastWithoutProceed(_ feature: PaidFeature) {
        // given
        let viewModel = self.makeViewModel(
            .init(feature: feature, licenseDays: 7), adResult: .unavailable
        )

        // when
        viewModel.watchAd()

        // then
        #expect(self.recorder.didFinishWith == [false])
        #expect(self.recorder.wasSheetClosedAtFinish == [true])
        #expect(self.gate.didGrantLicenseWith == nil)
        #expect(self.router?.didShowToastWithMessage == "paidFeature.adGuide::adUnavailable".localized())
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


// MARK: - 기본 테마 쓰기

extension PaidFeatureAdGuideViewModelImpleTests {

    @Test("기본 테마 쓰기를 고르면 시트가 닫힌 뒤 기본 테마 쓰기를 알리고 이어서 진행 안 함을 넘긴다")
    func useDefault_closesSheetThenNotifiesUseDefaultAndFinishesWithoutProceed() {
        // given
        let viewModel = self.makeViewModel(
            .init(feature: .colorTheme(isCustom: true), licenseDays: 7), withUseDefault: true
        )

        // when
        viewModel.useDefault()

        // then
        #expect(self.recorder.callbacks == [
            .useDefault(wasSheetClosed: true), .finished(false)
        ])
        #expect(self.gate.didGrantLicenseWith == nil)
    }

    @Test("기본 테마 쓰기를 고른 뒤 시트가 닫혔다는 알림이 와도 진행 안 함은 한 번만 넘긴다")
    func useDefault_thenSheetDismissed_finishesOnlyOnce() {
        // given
        let viewModel = self.makeViewModel(
            .init(feature: .colorTheme(isCustom: true), licenseDays: 7), withUseDefault: true
        )

        // when
        viewModel.useDefault()
        viewModel.handleSheetDismissed()

        // then
        #expect(self.recorder.callbacks == [
            .useDefault(wasSheetClosed: true), .finished(false)
        ])
    }

    @Test("기본 테마 쓰기를 거듭 골라도 기본 테마 쓰기와 진행 안 함은 한 번씩만 넘긴다")
    func useDefault_calledTwice_notifiesOnlyOnce() {
        // given
        let viewModel = self.makeViewModel(
            .init(feature: .colorTheme(isCustom: true), licenseDays: 7), withUseDefault: true
        )

        // when
        viewModel.useDefault()
        viewModel.useDefault()

        // then
        #expect(self.recorder.callbacks == [
            .useDefault(wasSheetClosed: true), .finished(false)
        ])
    }

    @Test("광고를 보는 중에 기본 테마 쓰기를 고르면 무시한다")
    func useDefault_whileWatchingAd_isIgnored() {
        // given
        let router = SpyAdGuideRouter(adResult: .rewarded)
        let recorder = self.recorder
        let viewModel = PaidFeatureAdGuideViewModelImple(
            reason: .init(feature: .colorTheme(isCustom: true), licenseDays: 7),
            paidFeatureGateUsecase: self.gate,
            accountUsecase: StubAccountUsecase(AccountInfo("uid")),
            onFinished: { [recorder] in recorder.callbacks.append(.finished($0)) },
            onUseDefault: { [recorder] in recorder.callbacks.append(.useDefault(wasSheetClosed: false)) }
        )
        viewModel.router = router
        router.onRouteToRewardedAd = { [weak viewModel] in viewModel?.useDefault() }

        // when
        viewModel.watchAd()

        // then
        #expect(self.recorder.callbacks == [.finished(true)])
    }

    @Test("기본 테마 쓰기 콜백을 받았는지에 따라 기본 테마 쓰기 선택지를 노출한다", arguments: [true, false])
    func canUseDefault_followsWhetherUseDefaultCallbackGiven(_ withUseDefault: Bool) async throws {
        // given
        let viewModel = self.makeViewModel(
            .init(feature: .colorTheme(isCustom: true), licenseDays: 7), withUseDefault: withUseDefault
        )

        // when
        let canUseDefault = try await self.firstOutput(
            self.expectConfirm("기본 테마 쓰기 노출"), for: viewModel.canUseDefault
        )

        // then
        #expect(canUseDefault == withUseDefault)
    }

    @Test("로그인 계정에만 플랜 보기 선택지를 노출한다", arguments: [true, false])
    func canShowPlans_onlyWhenSignedIn(_ isSignedIn: Bool) async throws {
        // given
        let viewModel = self.makeViewModel(
            .init(feature: .colorTheme(isCustom: true), licenseDays: 7), isSignedIn: isSignedIn
        )

        // when
        let canShowPlans = try await self.firstOutput(
            self.expectConfirm("플랜 보기 노출"), for: viewModel.canShowPlans
        )

        // then
        #expect(canShowPlans == isSignedIn)
    }
}
