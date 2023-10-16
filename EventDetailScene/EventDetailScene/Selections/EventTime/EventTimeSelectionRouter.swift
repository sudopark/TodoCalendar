//
//  
//  EventTimeSelectionRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/17/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol EventTimeSelectionRouting: Routing, Sendable { }

// MARK: - Router

final class EventTimeSelectionRouter: BaseRouterImple, EventTimeSelectionRouting, @unchecked Sendable { }


extension EventTimeSelectionRouter {
    
    private var currentScene: (any EventTimeSelectionScene)? {
        self.scene as? (any EventTimeSelectionScene)
    }
    
    // TODO: router implememnts
}
