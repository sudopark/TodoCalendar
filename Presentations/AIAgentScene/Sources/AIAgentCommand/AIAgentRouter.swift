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
}


// MARK: - AIAgentRouter

final class AIAgentRouter: BaseRouterImple, AIAgentRouting, @unchecked Sendable { }

extension AIAgentRouter {

    func openSystemSetting() {
        Task { @MainActor in
            guard let url = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(url)
            else { return }
            UIApplication.shared.open(url)
        }
    }
}
