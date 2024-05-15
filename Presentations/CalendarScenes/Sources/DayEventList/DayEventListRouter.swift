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
    
    func routeToMakeNewEvent(_ withParams: MakeEventParams)
    func routeToTodoEventDetail(_ eventId: String)
    func routeToScheduleEventDetail(_ eventId: String)
    // TODO: tempplate 관련해서 초기 파라미터 필요할 수 있음
    func routeToSelectTemplateForMakeEvent()
    func showDoneTodoList()
}

// MARK: - Router

final class DayEventListRouter: BaseRouterImple, DayEventListRouting, @unchecked Sendable {
    
    private let eventDetailSceneBuilder: any EventDetailSceneBuilder
    private let eventListSceneBuilder: any EventListSceneBuiler
    
    init(
        eventDetailSceneBuilder: any EventDetailSceneBuilder,
        eventListSceneBuilder: any EventListSceneBuiler
    ) {
        self.eventDetailSceneBuilder = eventDetailSceneBuilder
        self.eventListSceneBuilder = eventListSceneBuilder
    }
}


extension DayEventListRouter {
    
    // TODO: router implememnts
    
    func routeToMakeNewEvent(_ withParams: MakeEventParams) {
        Task { @MainActor in
            
            let next = self.eventDetailSceneBuilder.makeNewEventScene(withParams)
            self.scene?.present(next, animated: true)
        }
    }
    
    func routeToTodoEventDetail(_ eventId: String) {
        Task { @MainActor in
            let next = self.eventDetailSceneBuilder.makeTodoEventDetailScene(eventId)
            self.scene?.present(next, animated: true)
        }
    }
    
    func routeToScheduleEventDetail(_ eventId: String) {
        Task { @MainActor in
            let next = self.eventDetailSceneBuilder.makeScheduleEventDetailScene(eventId)
            self.scene?.present(next, animated: true)
        }
    }
    
    func routeToSelectTemplateForMakeEvent() {
        // TODO: route to tempplate select scene
    }
    
    func showDoneTodoList() {
        Task { @MainActor in
            let next = self.eventListSceneBuilder.makeDoneTodoEventListScene()
            self.scene?.present(next, animated: true)
        }
    }
}
