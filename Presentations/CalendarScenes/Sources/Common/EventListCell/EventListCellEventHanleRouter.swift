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
        calendarId: String, eventId: String
    )
    func routeToEditGoogleEvent(_ htmlLink: String)
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
    
    func routeToGoogleEventDetail(
        calendarId: String, eventId: String
    ) {
        Task { @MainActor in
            let next = self.eventDetailSceneBuilder.makeGoogleCalendarDetailScene(
                calendarId: calendarId,
                eventId: eventId
            )
            self.scene?.present(next, animated: true)
        }
    }
    
    func routeToEditGoogleEvent(_ htmlLink: String) {
        self.openSafari(htmlLink)
    }
    
    func routeToMakeNewEvent(_ withParams: MakeEventParams) {
        Task { @MainActor in
            
            let next = self.eventDetailSceneBuilder.makeNewEventScene(withParams)
            self.scene?.present(next, animated: true)
        }
    }
}
