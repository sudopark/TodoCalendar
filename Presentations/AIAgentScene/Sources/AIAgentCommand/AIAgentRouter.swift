//
//  AIAgentRouter.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - AIAgentRouting

protocol AIAgentRouting: Routing, Sendable {
    func openSystemSetting()
    func routeToPaywall()
}


// MARK: - AIAgentRouter

final class AIAgentRouter: BaseRouterImple, AIAgentRouting, @unchecked Sendable {

    private let paywallSceneBuilder: any PaywallSceneBuilder

    init(paywallSceneBuilder: any PaywallSceneBuilder) {
        self.paywallSceneBuilder = paywallSceneBuilder
        super.init()
    }
}

extension AIAgentRouter {

    func openSystemSetting() {
        Task { @MainActor in
            guard let url = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(url)
            else { return }
            UIApplication.shared.open(url)
        }
    }

    func routeToPaywall() {
        Task { @MainActor in
            let next = self.paywallSceneBuilder.makePaywallScene(closesAfterPurchase: true)
            self.showFullScreen(next)
        }
    }
}
