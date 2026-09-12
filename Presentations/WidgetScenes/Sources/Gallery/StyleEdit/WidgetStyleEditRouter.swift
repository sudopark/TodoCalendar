//
//  WidgetStyleEditRouter.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes
import CommonPresentation


protocol WidgetStyleEditRouting: Routing { }

final class WidgetStyleEditRouter: BaseRouterImple, WidgetStyleEditRouting, @unchecked Sendable {
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
    
    private var currentScene: (any WidgetStyleEditScene)? {
        self.scene as? (any WidgetStyleEditScene)
    }
}
