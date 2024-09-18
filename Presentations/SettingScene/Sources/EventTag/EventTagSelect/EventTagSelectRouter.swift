//
//  
//  EventTagSelectRouter.swift
//  SettingScene
//
//  Created by sudo.park on 1/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol EventTagSelectRouting: Routing, Sendable { }

// MARK: - Router

final class EventTagSelectRouter: BaseRouterImple, EventTagSelectRouting, @unchecked Sendable {
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        self.currentScene?.navigationController?.popViewController(animated: animate)
    }
}


extension EventTagSelectRouter {
    
    private var currentScene: (any EventTagSelectScene)? {
        self.scene as? (any EventTagSelectScene)
    }
    
    // TODO: router implememnts
}
