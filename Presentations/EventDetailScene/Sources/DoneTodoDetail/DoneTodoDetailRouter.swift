//
//  
//  DoneTodoDetailRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 2/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol DoneTodoDetailRouting: Routing, Sendable { }

// MARK: - Router

final class DoneTodoDetailRouter: BaseRouterImple, DoneTodoDetailRouting, @unchecked Sendable { }


extension DoneTodoDetailRouter {
    
    private var currentScene: (any DoneTodoDetailScene)? {
        self.scene as? (any DoneTodoDetailScene)
    }
    
    // TODO: router implememnts
}
