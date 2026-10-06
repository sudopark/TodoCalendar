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
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol ColorThemeSelectRouting: Routing, Sendable {
    
    func routeToEditCustomTheme(
        original: CustomColorTheme?,
        listener: (any ColorThemeEditSceneListener)?
    )
}

// MARK: - Router

final class ColorThemeSelectRouter: BaseRouterImple, ColorThemeSelectRouting, @unchecked Sendable { 
    
    private let editSceneBuilder: any ColorThemeEditSceneBuiler
    
    init(editSceneBuilder: any ColorThemeEditSceneBuiler) {
        self.editSceneBuilder = editSceneBuilder
    }
    
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
    
    func routeToEditCustomTheme(
        original: CustomColorTheme?,
        listener: (any ColorThemeEditSceneListener)?
    ) {
        Task { @MainActor in
            let next = self.editSceneBuilder.makeColorThemeEditScene(
                original: original, listener: listener
            )
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
}
