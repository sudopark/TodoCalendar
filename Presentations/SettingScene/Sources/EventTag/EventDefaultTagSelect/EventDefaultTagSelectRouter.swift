//
//  
//  EventDefaultTagSelectRouter.swift
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

protocol EventDefaultTagSelectRouting: Routing, Sendable { }

// MARK: - Router

final class EventDefaultTagSelectRouter: BaseRouterImple, EventDefaultTagSelectRouting, @unchecked Sendable {
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
}


extension EventDefaultTagSelectRouter {
    
    private var currentScene: (any EventDefaultTagSelectScene)? {
        self.scene as? (any EventDefaultTagSelectScene)
    }
    
    // TODO: router implememnts
}
