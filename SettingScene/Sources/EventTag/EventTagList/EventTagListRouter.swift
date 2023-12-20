//
//  
//  EventTagListRouter.swift
//  SettingScene
//
//  Created by sudo.park on 2023/09/24.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol EventTagListRouting: Routing, Sendable { 
    
    func routeToAddNewTag(listener: EventTagDetailSceneListener)
    
    func routeToEditTag(
        _ tagInfo: OriginalTagInfo,
        listener: EventTagDetailSceneListener
    )
}

// MARK: - Router

final class EventTagListRouter: BaseRouterImple, EventTagListRouting, @unchecked Sendable { 
    
    private let tagDetailSceneBuilder: any EventTagDetailSceneBuiler
    init(
        tagDetailSceneBuilder: any EventTagDetailSceneBuiler
    ) {
        self.tagDetailSceneBuilder = tagDetailSceneBuilder
    }
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        if let navigation = self.currentScene?.navigationController {
            navigation.popViewController(animated: animate)
            dismissed?()
        } else {
            self.currentScene?.dismiss(animated: animate, completion: dismissed)
        }
    }
}


extension EventTagListRouter {
    
    private var currentScene: (any EventTagListScene)? {
        self.scene as? (any EventTagListScene)
    }
    
    // TODO: router implememnts
    func routeToAddNewTag(listener: EventTagDetailSceneListener) {
        Task { @MainActor in
            let nextScene = self.tagDetailSceneBuilder.makeEventTagDetailScene(
                originalInfo: nil,
                listener: listener
            )
            self.currentScene?.present(nextScene, animated: true)
        }
    }
    
    func routeToEditTag(
        _ tagInfo: OriginalTagInfo,
        listener: EventTagDetailSceneListener
    ) {
        Task { @MainActor in
            let nextScene = self.tagDetailSceneBuilder.makeEventTagDetailScene(
                originalInfo: tagInfo,
                listener: listener
            )
            self.currentScene?.present(nextScene, animated: true)
        }
    }
}
