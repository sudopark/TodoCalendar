//
//  
//  SelectEventNotificationTimeRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 1/31/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SelectEventNotificationTimeRouting: Routing, Sendable { 
    
    func openSystemNotificationSetting()
}

// MARK: - Router

final class SelectEventNotificationTimeRouter: BaseRouterImple, SelectEventNotificationTimeRouting, @unchecked Sendable { }


extension SelectEventNotificationTimeRouter {
    
    private var currentScene: (any SelectEventNotificationTimeScene)? {
        self.scene as? (any SelectEventNotificationTimeScene)
    }
    
    func openSystemNotificationSetting() {
        // TODO: 
    }
}
