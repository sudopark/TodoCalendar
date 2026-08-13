//
//  GoogleCalendarEventEditScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes


// MARK: - Builder + DependencyInjector Extension

public protocol GoogleCalendarEventEditSceneBuiler: AnyObject {

    @MainActor
    func makeGoogleCalendarEventEditScene(
        calendarId: String, accountId: String, eventId: String,
        listener: (any GoogleCalendarEventEditSceneListener)?
    ) -> any GoogleCalendarEventEditScene
}
