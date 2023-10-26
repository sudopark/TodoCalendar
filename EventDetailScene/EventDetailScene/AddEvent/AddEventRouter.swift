//
//  
//  AddEventRouter.swift
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

protocol AddEventRouting: Routing, Sendable { 
    
    func routeToEventRepeatOptionSelect(
        startTime: Date,
        with initalOption: EventRepeating?
    )
    
    func routeToEventTagSelect(
        currentSelectedTagId: AllEventTagId
    )
}

// MARK: - Router

final class AddEventRouter: BaseRouterImple, AddEventRouting, @unchecked Sendable { 
    
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


extension AddEventRouter {
    
    private var currentScene: (any AddEventScene)? {
        self.scene as? (any AddEventScene)
    }
    
    // TODO: router implememnts
    func routeToEventRepeatOptionSelect(
        startTime: Date,
        with initalOption: EventRepeating?
    ) {
        Task { @MainActor in
            
            let next = self.selectRepeatOptionSceneBuilder.makeSelectEventRepeatOptionScene(
                startTime: startTime,
                previousSelected: initalOption,
                listener: self.currentScene?.interactor
            )
            self.currentScene?.present(next, animated: true)
        }
    }
    
    func routeToEventTagSelect(
        currentSelectedTagId: AllEventTagId
    ) {
        Task { @MainActor in
            
            let next = self.selectEventTagSceneBuilder.makeSelectEventTagScene(
                startWith: currentSelectedTagId,
                listener: self.currentScene?.interactor
            )
            
            let navigationController = UINavigationController(rootViewController: next)
            self.currentScene?.present(navigationController, animated: true)
        }
    }
}
