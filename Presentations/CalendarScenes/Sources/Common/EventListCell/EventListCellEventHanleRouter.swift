//
//  EventListCellEventHanleRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 6/28/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


protocol EventListCellEventHanleRouting: Routing, Sendable {
    
    func attach(_ scene: any Scene)
    func routeToTodoEventDetail(_ eventId: String)
    func routeToScheduleEventDetail(
        _ eventId: String,
        _ repeatingEventTargetTime: EventTime?
    )
    func routeToGoogleEventDetail(
        _ eventId: String
    )
    func routeToEditGoogleEvent(_ eventId: String)
    func routeToMakeNewEvent(_ withParams: MakeEventParams)
}


final class EventListCellEventHanleRouter: BaseRouterImple, EventListCellEventHanleRouting, @unchecked Sendable {
    
    private let eventDetailSceneBuilder: any EventDetailSceneBuilder
    
    weak var eventDetailListener: (any EventDetailSceneListener)?
    
    init(eventDetailSceneBuilder: any EventDetailSceneBuilder) {
        self.eventDetailSceneBuilder = eventDetailSceneBuilder
    }
}

extension EventListCellEventHanleRouter {
    
    func attach(_ scene: any Scene) {
        self.scene = scene
    }
    
    func routeToTodoEventDetail(_ eventId: String) {
        Task { @MainActor in
            let next = self.eventDetailSceneBuilder.makeTodoEventDetailScene(
                eventId, listener: self.eventDetailListener
            )
            self.scene?.present(next, animated: true)
        }
    }
    
    func routeToScheduleEventDetail(
        _ eventId: String,
        _ repeatingEventTargetTime: EventTime?
    ) {
        Task { @MainActor in
            let next = self.eventDetailSceneBuilder.makeScheduleEventDetailScene(
                eventId, repeatingEventTargetTime, listener: self.eventDetailListener
            )
            self.scene?.present(next, animated: true)
        }
    }
    
    func routeToGoogleEventDetail(_ eventId: String) {
        Task { @MainActor in
            // TODO: route to google event detail
        }
    }
    
    func routeToEditGoogleEvent(_ eventId: String) {
        Task { @MainActor in
            // TODO: route to edit google event
        }
    }
    
    func routeToMakeNewEvent(_ withParams: MakeEventParams) {
        Task { @MainActor in
            
            let next = self.eventDetailSceneBuilder.makeNewEventScene(withParams)
            self.scene?.present(next, animated: true)
        }
    }
}
