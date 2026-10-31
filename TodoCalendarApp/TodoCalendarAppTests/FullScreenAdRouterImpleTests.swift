//
//  FullScreenAdRouterImpleTests.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 10/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Testing
import Combine
import GoogleMobileAds
import AdService
import UnitTestHelpKit

@testable import TodoCalendarApp
import AdDomainInterface


@MainActor
final class FullScreenAdRouterImpleTests: AsyncEffectWaitable {

    private let spyAdService = SpyMobileAdService()

    private final class PresentedSettingScene {
        let window: UIWindow
        let host: UIViewController
        let setting: SettingNavigationController
        var didRequestAd: Bool = false

        init(window: UIWindow, host: UIViewController, setting: SettingNavigationController) {
            self.window = window
            self.host = host
            self.setting = setting
        }
    }

    private func makeRouter(canExposeAd: Bool = true) -> FullScreenAdRouterImple {
        return FullScreenAdRouterImple(
            adService: self.spyAdService,
            adExposureUsecase: StubAdExposureUsecase(canExpose: canExposeAd)
        )
    }

    private func makeSettingScenePresented(
        requesting router: FullScreenAdRouterImple
    ) async throws -> PresentedSettingScene {
        let window = UIWindow(frame: .init(x: 0, y: 0, width: 390, height: 844))
        let host = UIViewController()
        window.rootViewController = host
        window.makeKeyAndVisible()

        let presented = PresentedSettingScene(
            window: window,
            host: host,
            setting: SettingNavigationController(rootViewController: UIViewController())
        )
        presented.setting.onDismissed = {
            presented.didRequestAd = true
            router.show(from: presented.host, scope: .application, isFromAppLaunch: false)
        }
        var didPresent = false
        host.present(presented.setting, animated: false) { didPresent = true }
        try await self.waitEffect("설정 화면이 올라옴") { didPresent }
        return presented
    }
}


// MARK: - 설정 화면 이탈

extension FullScreenAdRouterImpleTests {

    @Test("유저가 설정 화면을 닫으면 전면광고를 띄운다")
    func router_whenSettingSceneDismissedByUser_takeAdToPresent() async throws {
        // given
        let router = self.makeRouter()
        let presented = try await self.makeSettingScenePresented(requesting: router)

        // when
        presented.setting.dismiss(animated: false)

        // then
        try await self.waitEffect("광고를 집어감") {
            self.spyAdService.didTakePreloadedFullScreenAd == true
        }
        withExtendedLifetime((router, presented)) { }
    }

    @Test("계정 전환으로 루트가 교체되며 설정 화면이 내려가면 전면광고를 띄우지 않는다")
    func router_whenSettingSceneTornDownByRootReplacement_doNotTakeAd() async throws {
        // given
        let router = self.makeRouter()
        let presented = try await self.makeSettingScenePresented(requesting: router)

        // when
        presented.window.rootViewController = UIViewController()
        try await self.waitEffect("닫힘이 광고 요청까지 닿음") { presented.didRequestAd }
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.spyAdService.didTakePreloadedFullScreenAd == nil)
        withExtendedLifetime((router, presented)) { }
    }

    @Test("노출 정책이 막으면 전면광고를 띄우지 않는다")
    func router_whenExposurePolicyRejects_doNotTakeAd() async throws {
        // given
        let router = self.makeRouter(canExposeAd: false)
        let presented = try await self.makeSettingScenePresented(requesting: router)

        // when
        presented.setting.dismiss(animated: false)
        try await self.waitEffect("닫힘이 광고 요청까지 닿음") { presented.didRequestAd }
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.spyAdService.didTakePreloadedFullScreenAd == nil)
        withExtendedLifetime((router, presented)) { }
    }

    @Test("윈도우에 붙지 않은 화면이 요청하면 전면광고를 띄우지 않는다")
    func router_whenRequestedFromViewControllerOutOfWindow_doNotTakeAd() async throws {
        // given
        let router = self.makeRouter()
        let viewController = UIViewController()
        viewController.loadViewIfNeeded()

        // when
        router.show(from: viewController, scope: .application, isFromAppLaunch: false)
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.spyAdService.didTakePreloadedFullScreenAd == nil)
        withExtendedLifetime((router, viewController)) { }
    }
}


private final class SpyMobileAdService: MobileAdService, @unchecked Sendable {

    var didTakePreloadedFullScreenAd: Bool?
    func takePreloadedFullScreenAd() -> InterstitialAd? {
        self.didTakePreloadedFullScreenAd = true
        return nil
    }

    var isStarted: AnyPublisher<Bool, Never> {
        return Just(true).eraseToAnyPublisher()
    }

    var isStartedNow: Bool { true }

    func start() { }

    @MainActor
    func presentConsentFormAndTrackingPromptIfNeeded(from viewController: UIViewController) async { }

    func preloadFullScreenAd() async { }

    func preloadRewardedAd() async { }

    func takeRewardedAd(waitingUpTo timeout: TimeInterval) async -> RewardedAd? { nil }

    @MainActor
    func isPrivacyOptionsRequired() -> Bool { false }

    @MainActor
    func showPrivacyOptionsForm(from viewController: UIViewController) async throws { }
}

private final class StubAdExposureUsecase: AdExposureUsecase, @unchecked Sendable {

    private let canExpose: Bool

    init(canExpose: Bool) {
        self.canExpose = canExpose
    }

    var isBannerAdAllowed: AnyPublisher<Bool, Never> {
        return Just(true).eraseToAnyPublisher()
    }

    func shouldPreloadFullScreenAds() -> Bool { true }

    func canExposeFullScreenAd(
        scope: FullScreenAdExposureRecord.Scope,
        isFromAppLaunch: Bool,
        at now: Date
    ) -> Bool {
        return self.canExpose
    }

    func recordFullScreenAdExposed(scope: FullScreenAdExposureRecord.Scope, at now: Date) { }
}
