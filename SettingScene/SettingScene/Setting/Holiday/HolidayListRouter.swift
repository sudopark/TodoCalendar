//
//  
//  HolidayListRouter.swift
//  SettingScene
//
//  Created by sudo.park on 11/26/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol HolidayListRouting: Routing, Sendable { }

// MARK: - Router

final class HolidayListRouter: BaseRouterImple, HolidayListRouting, @unchecked Sendable { }


extension HolidayListRouter {
    
    private var currentScene: (any HolidayListScene)? {
        self.scene as? (any HolidayListScene)
    }
    
    // TODO: router implememnts
}
