//
//  
//  EventSettingRouter.swift
//  SettingScene
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol EventSettingRouting: Routing, Sendable { 
    
    func routeToSelectTag()
}

// MARK: - Router

final class EventSettingRouter: BaseRouterImple, EventSettingRouting, @unchecked Sendable { }


extension EventSettingRouter {
    
    private var currentScene: (any EventSettingScene)? {
        self.scene as? (any EventSettingScene)
    }
    
    // TODO: router implememnts
    func routeToSelectTag() {
        
    }
    
}
