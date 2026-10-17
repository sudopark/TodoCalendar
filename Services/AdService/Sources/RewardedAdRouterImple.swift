//
//  RewardedAdRouterImple.swift
//  AdService
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import GoogleMobileAds
import Domain
import Extensions


public final class RewardedAdRouterImple: NSObject, @unchecked Sendable {

    private enum Constant {
        static let rewardedAdLoadTimeout: TimeInterval = 5
    }

    private enum Stage {
        case presentingRewarded(didEarnReward: Bool)
        case presentingFallback
    }

    private struct Session {
        var stage: Stage
        let ad: any FullScreenPresentingAd
        let completion: (RewardedAdResult) -> Void
        weak var viewController: UIViewController?
    }

    private let adService: any MobileAdService
    @MainActor private var session: Session?
    @MainActor private var isRequesting: Bool = false

    public init(adService: any MobileAdService) {
        self.adService = adService
        super.init()
    }

    @MainActor
    public func show(
        from viewController: UIViewController,
        completion: @escaping (RewardedAdResult) -> Void
    ) {
        guard self.isRequesting == false else {
            completion(.unavailable)
            return
        }
        self.isRequesting = true

        Task { [weak self, weak viewController] in
            let ad = await self?.adService.takeRewardedAd(
                waitingUpTo: Constant.rewardedAdLoadTimeout
            )
            await MainActor.run {
                guard let self else { return }
                guard let viewController else {
                    self.finish(.unavailable, completion: completion)
                    return
                }
                if let ad {
                    self.presentRewardedAd(ad, from: viewController, completion: completion)
                } else {
                    self.presentFallbackFullScreenAd(from: viewController, completion: completion)
                }
            }
        }
    }
}


// MARK: - present

extension RewardedAdRouterImple {

    @MainActor
    private func presentRewardedAd(
        _ ad: RewardedAd,
        from viewController: UIViewController,
        completion: @escaping (RewardedAdResult) -> Void
    ) {
        self.session = Session(
            stage: .presentingRewarded(didEarnReward: false),
            ad: ad,
            completion: completion,
            viewController: viewController
        )
        ad.fullScreenContentDelegate = self
        ad.present(from: viewController) { [weak self] in
            self?.session?.stage = .presentingRewarded(didEarnReward: true)
        }
    }

    @MainActor
    private func presentFallbackFullScreenAd(
        from viewController: UIViewController,
        completion: @escaping (RewardedAdResult) -> Void
    ) {
        guard let ad = self.adService.takePreloadedFullScreenAd() else {
            self.finish(.unavailable, completion: completion)
            return
        }
        self.session = Session(
            stage: .presentingFallback,
            ad: ad,
            completion: completion,
            viewController: viewController
        )
        ad.fullScreenContentDelegate = self
        ad.present(from: viewController)
    }

    @MainActor
    private func finish(
        _ result: RewardedAdResult,
        completion: @escaping (RewardedAdResult) -> Void
    ) {
        self.session = nil
        self.isRequesting = false
        completion(result)
        Task { [weak self] in
            await self?.adService.preloadRewardedAd()
            await self?.adService.preloadFullScreenAd()
        }
    }
}


// MARK: - FullScreenContentDelegate

extension RewardedAdRouterImple: FullScreenContentDelegate {

    public func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        guard let session = self.session else { return }
        switch session.stage {
        case .presentingRewarded(let didEarnReward):
            self.finish(
                didEarnReward ? .rewarded : .dismissedBeforeReward,
                completion: session.completion
            )
        case .presentingFallback:
            self.finish(.fallbackFullScreenShown, completion: session.completion)
        }
    }

    public func ad(
        _ ad: any FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        logger.log(level: .error, "rewarded flow ad present failed: \(error)")
        guard let session = self.session else { return }
        switch session.stage {
        case .presentingRewarded:
            guard let viewController = session.viewController else {
                self.finish(.unavailable, completion: session.completion)
                return
            }
            self.presentFallbackFullScreenAd(
                from: viewController, completion: session.completion
            )
        case .presentingFallback:
            self.finish(.unavailable, completion: session.completion)
        }
    }
}
