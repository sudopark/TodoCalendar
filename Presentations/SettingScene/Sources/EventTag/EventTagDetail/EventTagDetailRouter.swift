//
//  
//  EventTagDetailRouter.swift
//  SettingScene
//
//  Created by sudo.park on 2023/10/03.
//
//

import UIKit
import CommonPresentation
import SceneInfra
import SettingSceneInterface


// MARK: - Routing

protocol EventTagDetailRouting: Routing, Sendable { }

// MARK: - Router

final class EventTagDetailRouter: BaseRouterImple, EventTagDetailRouting, @unchecked Sendable { }


extension EventTagDetailRouter {
    
    private var currentScene: (any EventTagDetailScene)? {
        self.scene as? (any EventTagDetailScene)
    }
    
    // TODO: router implememnts
}
