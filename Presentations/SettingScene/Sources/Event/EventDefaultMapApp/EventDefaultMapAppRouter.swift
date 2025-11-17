//
//  
//  EventDefaultMapAppRouter.swift
//  SettingScene
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol EventDefaultMapAppRouting: Routing, Sendable { }

// MARK: - Router

final class EventDefaultMapAppRouter: BaseRouterImple, EventDefaultMapAppRouting, @unchecked Sendable {
    
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
}


extension EventDefaultMapAppRouter {
    
    private var currentScene: (any EventDefaultMapAppScene)? {
        self.scene as? (any EventDefaultMapAppScene)
    }
    
    // TODO: router implememnts
}
