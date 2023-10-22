//
//  
//  SelectEventTagRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SelectEventTagRouting: Routing, Sendable { }

// MARK: - Router

final class SelectEventTagRouter: BaseRouterImple, SelectEventTagRouting, @unchecked Sendable { }


extension SelectEventTagRouter {
    
    private var currentScene: (any SelectEventTagScene)? {
        self.scene as? (any SelectEventTagScene)
    }
    
    // TODO: router implememnts
}
