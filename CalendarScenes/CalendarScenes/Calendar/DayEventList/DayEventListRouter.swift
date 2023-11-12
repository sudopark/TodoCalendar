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
    func routeToTodoEventDetail(_ eventId: String)
    func routeToScheduleEventDetail(_ eventId: String)
    // TODO: tempplate 관련해서 초기 파라미터 필요할 수 있음
    func routeToSelectTemplateForMakeEvent()
}

// MARK: - Router

final class DayEventListRouter: BaseRouterImple, DayEventListRouting, @unchecked Sendable {
    
    private let eventDetailSceneBuilder: any EventDetailSceneBuilder
    
    init(eventDetailSceneBuilder: any EventDetailSceneBuilder) {
        self.eventDetailSceneBuilder = eventDetailSceneBuilder
    }
}


extension DayEventListRouter {
    
    private var currentScene: (any DayEventListScene)? {
        self.scene as? (any DayEventListScene)
    }
    
    // TODO: router implememnts
    
    func routeToMakeTodoEvent(_ withParams: TodoMakeParams) {
        Task { @MainActor in
            
            let next = self.eventDetailSceneBuilder.makeNewEventScene(isTodo: true)
            self.currentScene?.present(next, animated: true)
        }
    }
    
    func routeToMakeNewEvent() {
        Task { @MainActor in
            
            let next = self.eventDetailSceneBuilder.makeNewEventScene(isTodo: false)
            self.currentScene?.present(next, animated: true)
        }
    }
    
    func routeToTodoEventDetail(_ eventId: String) {
        Task { @MainActor in
            let next = self.eventDetailSceneBuilder.makeTodoEventDetailScene(eventId)
            self.currentScene?.present(next, animated: true)
        }
    }
    
    func routeToScheduleEventDetail(_ eventId: String) {
        Task { @MainActor in
            let next = self.eventDetailSceneBuilder.makeScheduleEventDetailScene(eventId)
            self.currentScene?.present(next, animated: true)
        }
    }
    
    func routeToSelectTemplateForMakeEvent() {
        // TODO: route to tempplate select scene
    }
}
