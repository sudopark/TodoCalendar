//
//  
//  ColorThemeSelectRouter.swift
//  SettingScene
//
//  Created by sudo.park on 8/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol ColorThemeSelectRouting: Routing, Sendable { }

// MARK: - Router

final class ColorThemeSelectRouter: BaseRouterImple, ColorThemeSelectRouting, @unchecked Sendable { 
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: true)
        }
    }
}


extension ColorThemeSelectRouter {
    
    private var currentScene: (any ColorThemeSelectScene)? {
        self.scene as? (any ColorThemeSelectScene)
    }
    
    // TODO: router implememnts
}
