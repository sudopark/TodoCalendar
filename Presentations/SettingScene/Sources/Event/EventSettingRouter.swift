//
//  
//  EventSettingRouter.swift
//  SettingScene
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol EventSettingRouting: Routing, Sendable {

    func routeToSelectTag()
    func routeToEventNotificationTime(forAllDay: Bool)
    func routeToSelectDefaultMapApp()
    func openSystemSetting()
}

// MARK: - Router

final class EventSettingRouter: BaseRouterImple, EventSettingRouting, @unchecked Sendable {
    
    private let eventTagSelectSceneBuilder: any EventTagSelectSceneBuiler
    private let eventDefaultNotificationTimeSceneBuilder: any EventNotificationDefaultTimeOptionSceneBuiler
    private let eventDefaultMapAppSceneBuilder: any EventDefaultMapAppSceneBuiler
    
    init(
        eventTagSelectSceneBuilder: any EventTagSelectSceneBuiler,
        eventDefaultNotificationTimeSceneBuilder: any EventNotificationDefaultTimeOptionSceneBuiler,
        eventDefaultMapAppSceneBuilder: any EventDefaultMapAppSceneBuiler
    ) {
        self.eventTagSelectSceneBuilder = eventTagSelectSceneBuilder
        self.eventDefaultNotificationTimeSceneBuilder = eventDefaultNotificationTimeSceneBuilder
        self.eventDefaultMapAppSceneBuilder = eventDefaultMapAppSceneBuilder
    }
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
}


extension EventSettingRouter {
    
    private var currentScene: (any EventSettingScene)? {
        self.scene as? (any EventSettingScene)
    }
    
    // TODO: router implememnts
    func routeToSelectTag() {
        Task { @MainActor in
            let next = self.eventTagSelectSceneBuilder.makeEventTagSelectScene()
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
    
    func routeToEventNotificationTime(forAllDay: Bool) {
        Task { @MainActor in
            let next = self.eventDefaultNotificationTimeSceneBuilder.makeEventNotificationDefaultTimeOptionScene(forAllDay: forAllDay)
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
    
    func routeToSelectDefaultMapApp() {
        Task { @MainActor in
            let next = self.eventDefaultMapAppSceneBuilder.makeEventDefaultMapAppScene()
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }

    func openSystemSetting() {
        Task { @MainActor in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
    }
}
