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

protocol GoogleCalendarEventDetailRouting: Routing, Sendable { }

// MARK: - Router

final class GoogleCalendarEventDetailRouter: BaseRouterImple, GoogleCalendarEventDetailRouting, @unchecked Sendable { }
