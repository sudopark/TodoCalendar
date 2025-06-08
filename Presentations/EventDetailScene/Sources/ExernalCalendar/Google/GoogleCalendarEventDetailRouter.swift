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
    
    func routeToEditEventWebView(_ link: String)
}

// MARK: - Router

final class GoogleCalendarEventDetailRouter: BaseRouterImple, GoogleCalendarEventDetailRouting, @unchecked Sendable { }


extension GoogleCalendarEventDetailRouter {
    
    private var currentScene: (any GoogleCalendarEventDetailScene)? {
        self.scene as? (any GoogleCalendarEventDetailScene)
    }
    
    func routeToEditEventWebView(_ link: String) {
        self.openSafari(link)
    }
}
