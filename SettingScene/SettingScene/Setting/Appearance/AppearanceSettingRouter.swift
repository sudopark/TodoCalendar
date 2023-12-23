//
//  
//  AppearanceSettingRouter.swift
//  SettingScene
//
//  Created by sudo.park on 12/3/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol AppearanceSettingRouting: Routing, Sendable {
    
    func routeToSelectTimeZone()
}

// MARK: - Router

final class AppearanceSettingRouter: BaseRouterImple, AppearanceSettingRouting, @unchecked Sendable { }


extension AppearanceSettingRouter {
    
    private var currentScene: (any AppearanceSettingScene)? {
        self.scene as? (any AppearanceSettingScene)
    }
    
    // TODO: router implememnts
    func routeToSelectTimeZone() {
        // TODO: 
    }
}
