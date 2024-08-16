//
//  
//  FeedbackPostRouter.swift
//  SettingScene
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol FeedbackPostRouting: Routing, Sendable { }

// MARK: - Router

final class FeedbackPostRouter: BaseRouterImple, FeedbackPostRouting, @unchecked Sendable { }


extension FeedbackPostRouter {
    
    private var currentScene: (any FeedbackPostScene)? {
        self.scene as? (any FeedbackPostScene)
    }
    
    // TODO: router implememnts
}
