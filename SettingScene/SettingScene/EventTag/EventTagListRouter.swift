//
//  
//  EventTagListRouter.swift
//  SettingScene
//
//  Created by sudo.park on 2023/09/24.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol EventTagListRouting: Routing, Sendable { }

// MARK: - Router

final class EventTagListRouter: BaseRouterImple, EventTagListRouting, @unchecked Sendable { }


extension EventTagListRouter {
    
    private var currentScene: (any EventTagListScene)? {
        self.scene as? (any EventTagListScene)
    }
    
    // TODO: router implememnts
}
