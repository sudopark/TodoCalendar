//
//  WidgetStyleLicenseGuideTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import Extensions
import Scenes
import TestDoubles

@testable import WidgetScenes


class SpyWidgetStyleLicenseGuideRouter: BaseSpyRouter, WidgetStyleLicenseGuideRouting, @unchecked Sendable {

    var didRequestRewardedAd: Bool = false
    private var onAdFinished: (@Sendable (RewardedAdResult) -> Void)?

    func routeToRewardedAd(completion: @escaping @Sendable (RewardedAdResult) -> Void) {
        self.didRequestRewardedAd = true
        self.onAdFinished = completion
    }

    func finishRewardedAd(with result: RewardedAdResult) {
        self.onAdFinished?(result)
    }

    var didRouteToPaywall: Bool = false
    func routeToPaywall() {
        self.didRouteToPaywall = true
    }

    func selectSheetAction(_ key: String) {
        self.actionSheetSelectionMocking = { form in
            form.actions.first(where: { $0.text == key.localized() })
        }
    }
}


private final class ContinuationCounter: @unchecked Sendable {
    var didContinueCount: Int = 0
}


struct WidgetStyleLicenseGuideTests {

    private func makeGuide(
        licenseDays: Int? = 7
    ) -> (WidgetStyleLicenseGuide, SpyWidgetStyleLicenseGuideRouter, StubWidgetStylePaidFeatureGateUsecase) {
        let gate = StubWidgetStylePaidFeatureGateUsecase()
        gate.licenseDays = licenseDays
        let router = SpyWidgetStyleLicenseGuideRouter()
        let guide = WidgetStyleLicenseGuide(paidFeatureGateUsecase: gate)
        guide.router = router
        return (guide, router, gate)
    }

    private func watchAd(
        finishWith result: RewardedAdResult
    ) -> (SpyWidgetStyleLicenseGuideRouter, StubWidgetStylePaidFeatureGateUsecase, ContinuationCounter) {
        let (guide, router, gate) = self.makeGuide()
        let counter = ContinuationCounter()
        router.selectSheetAction("widget.style.license::watchAd")
        guide.show { counter.didContinueCount += 1 }
        router.finishRewardedAd(with: result)
        return (router, gate, counter)
    }

    @Test("보상형 광고를 다 보면 사용권을 기록하고 이어서 한다")
    func guide_rewarded_grantsAndContinues() {
        // given + when
        let (router, gate, counter) = self.watchAd(finishWith: .rewarded)

        // then
        #expect(router.didRequestRewardedAd == true)
        #expect(gate.didGrantLicenseAt != nil)
        #expect(counter.didContinueCount == 1)
    }

    @Test("보상형 대신 전면 광고를 보여줘도 사용권을 기록하고 이어서 한다")
    func guide_fallbackFullScreen_grantsAndContinues() {
        // given + when
        let (_, gate, counter) = self.watchAd(finishWith: .fallbackFullScreenShown)

        // then
        #expect(gate.didGrantLicenseAt != nil)
        #expect(counter.didContinueCount == 1)
    }

    @Test("광고를 불러오지 못하면 알림만 띄우고 사용권도 이어서 하기도 없다")
    func guide_unavailable_showsToast() {
        // given + when
        let (router, gate, counter) = self.watchAd(finishWith: .unavailable)

        // then
        #expect(router.didShowToastWithMessage == "widget.style.license::adUnavailable".localized())
        #expect(gate.didGrantLicenseAt == nil)
        #expect(counter.didContinueCount == 0)
    }

    @Test("보상 전에 광고를 닫으면 아무 일도 없다")
    func guide_dismissedBeforeReward_doesNothing() {
        // given + when
        let (router, gate, counter) = self.watchAd(finishWith: .dismissedBeforeReward)

        // then
        #expect(router.didShowToastWithMessage == nil)
        #expect(gate.didGrantLicenseAt == nil)
        #expect(counter.didContinueCount == 0)
    }

    @Test("사용권 기간을 해석할 수 없으면 안내 없이 광고 없음을 알린다")
    func guide_noLicenseDays_showsToastWithoutSheet() {
        // given
        let (guide, router, _) = self.makeGuide(licenseDays: nil)
        let counter = ContinuationCounter()

        // when
        guide.show { counter.didContinueCount += 1 }

        // then
        #expect(router.didShowActionSheetWith == nil)
        #expect(router.didShowToastWithMessage == "widget.style.license::adUnavailable".localized())
        #expect(counter.didContinueCount == 0)
    }

    @Test("플랜 보기를 고르면 paywall 만 연다")
    func guide_showPlans_routesToPaywallOnly() {
        // given
        let (guide, router, gate) = self.makeGuide()
        let counter = ContinuationCounter()
        router.selectSheetAction("widget.style.license::showPlans")

        // when
        guide.show { counter.didContinueCount += 1 }

        // then
        #expect(router.didRouteToPaywall == true)
        #expect(router.didRequestRewardedAd == false)
        #expect(gate.didGrantLicenseAt == nil)
        #expect(counter.didContinueCount == 0)
    }

    @Test("안내를 취소하면 광고도 paywall 도 없다")
    func guide_canceled_doesNothing() {
        // given
        let (guide, router, _) = self.makeGuide()
        let counter = ContinuationCounter()
        router.selectSheetAction("common.cancel")

        // when
        guide.show { counter.didContinueCount += 1 }

        // then
        #expect(router.didShowActionSheetWith != nil)
        #expect(router.didRequestRewardedAd == false)
        #expect(router.didRouteToPaywall == false)
        #expect(counter.didContinueCount == 0)
    }
}
