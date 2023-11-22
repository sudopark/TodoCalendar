//
//  
//  SettingItemListRouter.swift
//  SettingScene
//
//  Created by sudo.park on 11/21/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SettingItemListRouting: Routing, Sendable { }

// MARK: - Router

final class SettingItemListRouter: BaseRouterImple, SettingItemListRouting, @unchecked Sendable { }


extension SettingItemListRouter {
    
    private var currentScene: (any SettingItemListScene)? {
        self.scene as? (any SettingItemListScene)
    }
    
    // TODO: router implememnts
}
