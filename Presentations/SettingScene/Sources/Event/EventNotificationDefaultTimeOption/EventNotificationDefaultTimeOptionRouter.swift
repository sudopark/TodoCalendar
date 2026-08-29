//
//  
//  EventNotificationDefaultTimeOptionRouter.swift
//  SettingScene
//
//  Created by sudo.park on 1/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol EventNotificationDefaultTimeOptionRouting: Routing, Sendable { }

// MARK: - Router

final class EventNotificationDefaultTimeOptionRouter: BaseRouterImple, EventNotificationDefaultTimeOptionRouting, @unchecked Sendable { 
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
}


extension EventNotificationDefaultTimeOptionRouter {
    
    private var currentScene: (any EventNotificationDefaultTimeOptionScene)? {
        self.scene as? (any EventNotificationDefaultTimeOptionScene)
    }
}
