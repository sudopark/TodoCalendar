//
//  OpenSourceLicenseRouter.swift
//  SettingScene
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol OpenSourceLicenseRouting: Routing, Sendable { }

// MARK: - Router

final class OpenSourceLicenseRouter: BaseRouterImple, OpenSourceLicenseRouting, @unchecked Sendable {
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
}


extension OpenSourceLicenseRouter {
    
    private var currentScene: (any OpenSourceLicenseScene)? {
        self.scene as? (any OpenSourceLicenseScene)
    }
}
