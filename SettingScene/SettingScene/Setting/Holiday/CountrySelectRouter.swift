//
//  
//  CountrySelectRouter.swift
//  SettingScene
//
//  Created by sudo.park on 12/1/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol CountrySelectRouting: Routing, Sendable { }

// MARK: - Router

final class CountrySelectRouter: BaseRouterImple, CountrySelectRouting, @unchecked Sendable { }


extension CountrySelectRouter {
    
    private var currentScene: (any CountrySelectScene)? {
        self.scene as? (any CountrySelectScene)
    }
    
    // TODO: router implememnts
}
