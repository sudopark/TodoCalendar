//
//  
//  GoogleCalendarEventDetailRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol GoogleCalendarEventDetailRouting: Routing, Sendable {

    func routeToEditEvent(
        calendarId: String, accountId: String, eventId: String,
        listener: (any GoogleCalendarEventEditSceneListener)?
    )
}

// MARK: - Router

final class GoogleCalendarEventDetailRouter: BaseRouterImple, GoogleCalendarEventDetailRouting, @unchecked Sendable {

    private let editSceneBuilder: any GoogleCalendarEventEditSceneBuiler

    init(editSceneBuilder: any GoogleCalendarEventEditSceneBuiler) {
        self.editSceneBuilder = editSceneBuilder
    }
}


extension GoogleCalendarEventDetailRouter {

    private var currentScene: (any GoogleCalendarEventDetailScene)? {
        self.scene as? (any GoogleCalendarEventDetailScene)
    }

    func routeToEditEvent(
        calendarId: String, accountId: String, eventId: String,
        listener: (any GoogleCalendarEventEditSceneListener)?
    ) {
        Task { @MainActor in
            let next = self.editSceneBuilder.makeGoogleCalendarEventEditScene(
                calendarId: calendarId, accountId: accountId, eventId: eventId,
                listener: listener
            )
            self.currentScene?.present(next, animated: true)
        }
    }
}
