//
//  AppleCalendarEventDetailScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 4/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes


// MARK: - Builder + DependencyInjector Extension

public protocol AppleCalendarEventDetailSceneBuilder: AnyObject {

    @MainActor
    func makeAppleCalendarEventDetailScene(
        calendarId: String, eventId: String
    ) -> any AppleCalendarEventDetailScene
}
