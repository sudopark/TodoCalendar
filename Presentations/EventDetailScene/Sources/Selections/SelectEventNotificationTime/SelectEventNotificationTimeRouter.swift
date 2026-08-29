//
//  
//  SelectEventNotificationTimeRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 1/31/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import Foundation
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SelectEventNotificationTimeRouting: Routing, Sendable { }

// MARK: - Router

final class SelectEventNotificationTimeRouter: BaseRouterImple, SelectEventNotificationTimeRouting, @unchecked Sendable { }
