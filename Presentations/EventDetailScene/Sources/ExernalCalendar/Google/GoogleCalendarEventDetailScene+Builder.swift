//
//  
//  GoogleCalendarEventDetailScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes


// MARK: - Builder + DependencyInjector Extension

public protocol GoogleCalendarEventDetailSceneBuiler: AnyObject {
    
    @MainActor
    func makeGoogleCalendarEventDetailScene(
        calendarId: String, eventId: String
    ) -> any GoogleCalendarEventDetailScene
}
