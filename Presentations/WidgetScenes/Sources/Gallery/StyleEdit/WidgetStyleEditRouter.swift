//
//  WidgetStyleEditRouter.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


protocol WidgetStyleEditRouting: Routing {

    func routeToPhotoPick(onPick: @escaping @Sendable (Data?) -> Void)
    func routeToRewardedAd(completion: @escaping @Sendable (RewardedAdResult) -> Void)
    func routeToPaywall()
}

final class WidgetStyleEditRouter: BaseRouterImple, WidgetStyleEditRouting, @unchecked Sendable {

    // 시스템 피커가 delegate 를 weak 으로 잡아 호출측이 붙들고 있어야 한다
    private let imagePicker: ImagePicker = .init()
    private let paywallSceneBuilder: any PaywallSceneBuilder
    // 광고 라우터가 해제되면 광고 결과 콜백이 오지 않아 Router 가 붙잡는다
    private let rewardedAdRouter: any RewardedAdRouter

    init(
        paywallSceneBuilder: any PaywallSceneBuilder,
        rewardedAdRouter: any RewardedAdRouter
    ) {
        self.paywallSceneBuilder = paywallSceneBuilder
        self.rewardedAdRouter = rewardedAdRouter
    }
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
    
    private var currentScene: (any WidgetStyleEditScene)? {
        self.scene as? (any WidgetStyleEditScene)
    }
}


extension WidgetStyleEditRouter {

    func routeToPhotoPick(onPick: @escaping @Sendable (Data?) -> Void) {
        Task { @MainActor in
            let picker = self.imagePicker.makeViewController(source: .photoLibrary) { data in
                onPick(data)
            }
            self.scene?.present(picker, animated: true)
        }
    }

    func routeToRewardedAd(completion: @escaping @Sendable (RewardedAdResult) -> Void) {
        Task { @MainActor in
            guard let scene = self.scene else {
                completion(.dismissedBeforeReward)
                return
            }
            self.rewardedAdRouter.showRewardedAd(from: scene) { completion($0) }
        }
    }

    func routeToPaywall() {
        Task { @MainActor in
            let paywall = self.paywallSceneBuilder.makePaywallScene(closesAfterPurchase: true)
            self.showFullScreen(paywall)
        }
    }
}
