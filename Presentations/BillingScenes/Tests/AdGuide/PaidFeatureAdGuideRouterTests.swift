//
//  PaidFeatureAdGuideRouterTests.swift
//  BillingScenesTests
//
//  Created by sudo.park on 10/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit
import Domain
import Scenes
import CommonPresentation
import UnitTestHelpKit
import TestDoubles

@testable import BillingScenes


private final class StubRewardedAdRouter: RewardedAdRouter, @unchecked Sendable {

    let result: RewardedAdResult
    private(set) var didShowFrom: UIViewController?
    init(result: RewardedAdResult) {
        self.result = result
    }

    @MainActor
    func showRewardedAd(
        from viewController: UIViewController,
        completion: @escaping (RewardedAdResult) -> Void
    ) {
        self.didShowFrom = viewController
        completion(self.result)
    }
}

private final class DummyPaywallScene: UIViewController, PaywallScene {

    var interactor: (any PaywallSceneInteractor)?
    let viewAppearance: ViewAppearance = makeDummyAppearance()
}

private final class SpyPaywallSceneBuilder: PaywallSceneBuilder, @unchecked Sendable {

    private(set) var didMakePaywallClosesAfterPurchase: Bool?

    @MainActor
    func makePaywallScene(closesAfterPurchase: Bool) -> any PaywallScene {
        self.didMakePaywallClosesAfterPurchase = closesAfterPurchase
        return DummyPaywallScene()
    }
}

private final class SpyPresenter: UIViewController {

    private(set) var didPresent: UIViewController?

    override func present(
        _ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil
    ) {
        self.didPresent = viewControllerToPresent
        completion?()
    }
}

private final class DummySheetScene: UIViewController, Scenes.Scene {

    var interactor: EmptyInteractor? { nil }
    let viewAppearance: ViewAppearance = makeDummyAppearance()
    var presenter: UIViewController?
    private(set) var didDismissCount = 0

    override var presentingViewController: UIViewController? { self.presenter }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.didDismissCount += 1
        completion?()
    }
}

private func makeDummyAppearance() -> ViewAppearance {
    return ViewAppearance(
        setting: AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        ),
        isSystemDarkTheme: false
    )
}

private final class ResultRecorder: @unchecked Sendable {
    var didReceiveResults: [RewardedAdResult] = []
}


@MainActor
final class PaidFeatureAdGuideRouterTests: AsyncEffectWaitable {

    private let paywallBuilder = SpyPaywallSceneBuilder()
    private let presenter = SpyPresenter()
    private let recorder = ResultRecorder()
    private var sheet: DummySheetScene?
    private var adRouter: StubRewardedAdRouter?

    private func makeRouter(
        adResult: RewardedAdResult = .rewarded,
        hasScene: Bool = true
    ) -> PaidFeatureAdGuideRouter {
        let adRouter = StubRewardedAdRouter(result: adResult)
        self.adRouter = adRouter
        let router = PaidFeatureAdGuideRouter(
            rewardedAdRouter: adRouter, paywallSceneBuilder: self.paywallBuilder
        )
        let sheet = DummySheetScene()
        sheet.presenter = self.presenter
        self.sheet = sheet
        router.scene = hasScene ? sheet : nil
        return router
    }
}


// MARK: - 광고·paywall 경로

extension PaidFeatureAdGuideRouterTests {

    @Test("광고는 시트를 닫지 않고 시트 위에 띄우고, 그 결과를 그대로 넘긴다")
    func routeToRewardedAd_showsAdOverSheet() async throws {
        // given
        let router = self.makeRouter(adResult: .fallbackFullScreenShown)

        // when
        router.routeToRewardedAd { [recorder] in recorder.didReceiveResults.append($0) }
        try await self.waitEffect("광고 결과") { self.recorder.didReceiveResults.isEmpty == false }

        // then
        #expect(self.sheet?.didDismissCount == 0)
        #expect(self.adRouter?.didShowFrom === self.sheet)
        #expect(self.recorder.didReceiveResults == [.fallbackFullScreenShown])
    }

    @Test("시트가 없으면 광고 없이 보상 전 닫음으로 끝낸다")
    func routeToRewardedAd_whenNoSheet_finishesWithoutAd() async throws {
        // given
        let router = self.makeRouter(hasScene: false)

        // when
        router.routeToRewardedAd { [recorder] in recorder.didReceiveResults.append($0) }
        try await self.waitEffect("광고 없음 결과") { self.recorder.didReceiveResults.isEmpty == false }

        // then
        #expect(self.adRouter?.didShowFrom == nil)
        #expect(self.recorder.didReceiveResults == [.dismissedBeforeReward])
    }

    @Test("paywall 은 시트를 닫은 뒤 시트를 띄운 화면에서 구매 뒤 닫히는 형태로 띄운다")
    func routeToPaywall_dismissesSheetAndPresentsPaywallFromPresenter() async throws {
        // given
        let router = self.makeRouter()

        // when
        router.routeToPaywall()
        try await self.waitEffect("paywall 표시") { self.presenter.didPresent != nil }

        // then
        #expect(self.sheet?.didDismissCount == 1)
        #expect(self.paywallBuilder.didMakePaywallClosesAfterPurchase == true)
        #expect(self.presenter.didPresent is DummyPaywallScene)
    }
}
