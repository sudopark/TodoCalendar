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
    func routeToSelectTodoSkipTime(_ eventId: String)
}


final class EventListCellEventHanleRouter: BaseRouterImple, EventListCellEventHanleRouting, @unchecked Sendable {
    
    private let eventDetailSceneBuilder: any EventDetailSceneBuilder
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
            let next = self.eventDetailSceneBuilder.makeTodoEventDetailScene(eventId)
            self.scene?.present(next, animated: true)
        }
    }
    
    func routeToScheduleEventDetail(
        _ eventId: String,
        _ repeatingEventTargetTime: EventTime?
    ) {
        Task { @MainActor in
            let next = self.eventDetailSceneBuilder.makeScheduleEventDetailScene(
                eventId, repeatingEventTargetTime
            )
            self.scene?.present(next, animated: true)
        }
    }
    
    func routeToSelectTodoSkipTime(_ eventId: String) {
        // TODO: 
    }
}
