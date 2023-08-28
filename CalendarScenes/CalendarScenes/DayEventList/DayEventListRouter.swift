//
//  
//  DayEventListRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol DayEventListRouting: Routing, Sendable { }

// MARK: - Router

final class DayEventListRouter: BaseRouterImple, DayEventListRouting, @unchecked Sendable { }


extension DayEventListRouter {
    
    private var currentScene: (any DayEventListScene)? {
        self.scene as? (any DayEventListScene)
    }
    
    // TODO: router implememnts
}
