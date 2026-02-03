//
//  WidgetAppearanceSettingRouter.swift
//  SettingScene
//
//  Created by sudo.park on 2/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes
import CommonPresentation


protocol WidgetAppearanceSettingRouting: Routing { }

final class WidgetAppearanceSettingRouter: BaseRouterImple, WidgetAppearanceSettingRouting, @unchecked Sendable {
    
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: true)
        }
    }
    
    private var currentScene: (any WidgetAppearanceSettingScene)? {
        self.scene as? (any WidgetAppearanceSettingScene)
    }
}
