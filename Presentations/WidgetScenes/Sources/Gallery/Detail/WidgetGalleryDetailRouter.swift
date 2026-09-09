//
//  WidgetGalleryDetailRouter.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes
import CommonPresentation


protocol WidgetGalleryDetailRouting: Routing { }

final class WidgetGalleryDetailRouter: BaseRouterImple, WidgetGalleryDetailRouting, @unchecked Sendable {
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
    
    private var currentScene: (any WidgetGalleryDetailScene)? {
        self.scene as? (any WidgetGalleryDetailScene)
    }
}
