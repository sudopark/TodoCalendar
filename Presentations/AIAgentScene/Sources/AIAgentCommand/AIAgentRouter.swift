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

    // 한도 초과 실패 화면의 "플랜 보기" — 전체화면으로 열어 시트 위에도 뜨게 한다 (#739)
    func routeToPaywall() {
        Task { @MainActor in
            let next = self.paywallSceneBuilder.makePaywallScene()
            self.showFullScreen(next)
        }
    }
}
