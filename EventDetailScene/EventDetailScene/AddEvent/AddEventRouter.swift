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
}

// MARK: - Router

final class AddEventRouter: BaseRouterImple, AddEventRouting, @unchecked Sendable { 
    
    private let selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler
    
    init(
        selectRepeatOptionSceneBuilder: any SelectEventRepeatOptionSceneBuiler
    ) {
        self.selectRepeatOptionSceneBuilder = selectRepeatOptionSceneBuilder
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
}
