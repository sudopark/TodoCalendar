//
//  
//  DayEventListRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol DayEventListRouting: Routing, Sendable {
    
    func routeToMakeTodoEvent(_ withParams: TodoMakeParams)
    func routeToMakeNewEvent()
    // TODO: tempplate 관련해서 초기 파라미터 필요할 수 있음
    func routeToSelectTemplateForMakeEvent()
}

// MARK: - Router

final class DayEventListRouter: BaseRouterImple, DayEventListRouting, @unchecked Sendable { }


extension DayEventListRouter {
    
    private var currentScene: (any DayEventListScene)? {
        self.scene as? (any DayEventListScene)
    }
    
    // TODO: router implememnts
    
    func routeToMakeTodoEvent(_ withParams: TodoMakeParams) {
        // TODO: route to make todo scene
    }
    
    func routeToMakeNewEvent() {
        // TODO: route to make new event scene
    }
    
    func routeToSelectTemplateForMakeEvent() {
        // TODO: route to tempplate select scene
    }
}
