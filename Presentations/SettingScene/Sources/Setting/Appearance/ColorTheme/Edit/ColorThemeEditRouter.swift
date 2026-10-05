//
//  ColorThemeEditRouter.swift
//  SettingScene
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol ColorThemeEditRouting: Routing, Sendable { }

// MARK: - Router

final class ColorThemeEditRouter: BaseRouterImple, ColorThemeEditRouting, @unchecked Sendable {

    override func closeScene(animate: Bool, _ dismissed: (@Sendable () -> Void)?) {
        Task { @MainActor in
            self.scene?.navigationController?.popViewController(animated: animate)
            dismissed?()
        }
    }
}
