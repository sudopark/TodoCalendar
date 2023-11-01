//
//  
//  EventDetailRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/15/23.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol EventDetailRouting: Routing, Sendable { 
    
    func routeToEventRepeatOptionSelect(
        startTime: Date,
        with initalOption: EventRepeating?,
        listener: (any SelectEventRepeatOptionSceneListener)?
    )
    
    func routeToEventTagSelect(
        currentSelectedTagId: AllEventTagId,
        listener: (any SelectEventTagSceneListener)?
    )
}

// MARK: - Router

final class EventDetailRouter: BaseRouterImple, EventDetailRouting, @unchecked Sendable { 
    
    private let selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler
    private let selectEventTagSceneBuilder: any SelectEventTagSceneBuiler
    
    init(
        selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler,
        selectEventTagSceneBuilder: any SelectEventTagSceneBuiler
    ) {
        self.selectRepeatOptionSceneBuilder = selectRepeatOptionSceneBuilder
        self.selectEventTagSceneBuilder = selectEventTagSceneBuilder
    }
}


extension EventDetailRouter {
    
    private var currentScene: (any EventDetailScene)? {
        self.scene as? (any EventDetailScene)
    }
    
    // TODO: router implememnts
    func routeToEventRepeatOptionSelect(
        startTime: Date,
        with initalOption: EventRepeating?,
        listener: (any SelectEventRepeatOptionSceneListener)?
    ) {
        Task { @MainActor in
            
            let next = self.selectRepeatOptionSceneBuilder.makeSelectEventRepeatOptionScene(
                startTime: startTime,
                previousSelected: initalOption,
                listener: listener
            )
            self.currentScene?.present(next, animated: true)
        }
    }
    
    func routeToEventTagSelect(
        currentSelectedTagId: AllEventTagId,
        listener: (any SelectEventTagSceneListener)?
    ) {
        Task { @MainActor in
            
            let next = self.selectEventTagSceneBuilder.makeSelectEventTagScene(
                startWith: currentSelectedTagId,
                listener: listener
            )
            
            let navigationController = UINavigationController(rootViewController: next)
            self.currentScene?.present(navigationController, animated: true)
        }
    }
}
