//
//  AppleCalendarEventDetailRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 4/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol AppleCalendarEventDetailRouting: Routing, Sendable {
    func routeToAppleCalendarApp(at interval: TimeInterval)
    func openURL(_ urlString: String)
}

// MARK: - Router

final class AppleCalendarEventDetailRouter: BaseRouterImple, AppleCalendarEventDetailRouting, @unchecked Sendable { }


extension AppleCalendarEventDetailRouter {

    private var currentScene: (any AppleCalendarEventDetailScene)? {
        self.scene as? (any AppleCalendarEventDetailScene)
    }

    func routeToAppleCalendarApp(at interval: TimeInterval) {
        // calshow: scheme uses seconds since 2001-01-01 (Core Data reference date)
        let referenceInterval = interval - 978307200
        guard let url = URL(string: "calshow:\(referenceInterval)") else { return }
        UIApplication.shared.open(url)
    }

    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
