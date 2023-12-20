//
//  
//  SelectEventRepeatOptionRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SelectEventRepeatOptionRouting: Routing, Sendable { }

// MARK: - Router

final class SelectEventRepeatOptionRouter: BaseRouterImple, SelectEventRepeatOptionRouting, @unchecked Sendable { }


extension SelectEventRepeatOptionRouter {
    
    private var currentScene: (any SelectEventRepeatOptionScene)? {
        self.scene as? (any SelectEventRepeatOptionScene)
    }
    
    // TODO: router implememnts
}
