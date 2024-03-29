//
//  
//  SelectEventTagRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SelectEventTagRouting: Routing, Sendable { 
    
    func routeToAddNewTagScene()
    func routeToTagListScene()
}

// MARK: - Router

final class SelectEventTagRouter: BaseRouterImple, SelectEventTagRouting, @unchecked Sendable { 
    
    private let settingSceneBuilder: any SettingSceneBuiler
    
    init(
        settingSceneBuilder: any SettingSceneBuiler
    ) {
        self.settingSceneBuilder = settingSceneBuilder
    }
}


extension SelectEventTagRouter {
    
    private var currentScene: (any SelectEventTagScene)? {
        self.scene as? (any SelectEventTagScene)
    }
    
    // TODO: router implememnts
    func routeToAddNewTagScene() {
        Task { @MainActor in
            
            let next = self.settingSceneBuilder.makeEventTagDetailScene(
                originalInfo: nil,
                listener: self.currentScene?.interactor
            )
            self.currentScene?.present(next, animated: true)
        }
    }
    
    func routeToTagListScene() {
        
        Task { @MainActor in
            
            let next = self.settingSceneBuilder.makeEventTagListScene(
                hasNavigation: true,
                listener: self.currentScene?.interactor
            )
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
}
