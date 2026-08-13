//
//  GoogleCalendarEventEditRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol GoogleCalendarEventEditRouting: Routing, Sendable { }

// MARK: - Router

final class GoogleCalendarEventEditRouter: BaseRouterImple, GoogleCalendarEventEditRouting, @unchecked Sendable { }
