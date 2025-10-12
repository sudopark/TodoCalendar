//
//  
//  HolidayEventDetailRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol HolidayEventDetailRouting: Routing, Sendable { }

// MARK: - Router

final class HolidayEventDetailRouter: BaseRouterImple, HolidayEventDetailRouting, @unchecked Sendable { }


extension HolidayEventDetailRouter {
    
    private var currentScene: (any HolidayEventDetailScene)? {
        self.scene as? (any HolidayEventDetailScene)
    }
    
    // TODO: router implememnts
}
