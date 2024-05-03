//
//  
//  SelectEventTimeRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/4/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SelectEventTimeRouting: Routing, Sendable { }

// MARK: - Router

final class SelectEventTimeRouter: BaseRouterImple, SelectEventTimeRouting, @unchecked Sendable { }


extension SelectEventTimeRouter {
    
    private var currentScene: (any SelectEventTimeScene)? {
        self.scene as? (any SelectEventTimeScene)
    }
    
    // TODO: router implememnts
}
