//
//  
//  AddEventRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/15/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol AddEventRouting: Routing, Sendable { }

// MARK: - Router

final class AddEventRouter: BaseRouterImple, AddEventRouting, @unchecked Sendable { }


extension AddEventRouter {
    
    private var currentScene: (any AddEventScene)? {
        self.scene as? (any AddEventScene)
    }
    
    // TODO: router implememnts
}
