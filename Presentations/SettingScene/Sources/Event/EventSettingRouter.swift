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
import CommonPresentation
import SceneInfra


// MARK: - Routing

protocol EventSettingRouting: Routing, Sendable {

    func routeToSelectTag()
    func routeToEventNotificationTime(forAllDay: Bool)
    func routeToSelectDefaultMapApp()
    func routeToSelectGoogleCalendars(accountId: String)
}

// MARK: - Router

final class EventSettingRouter: BaseRouterImple, EventSettingRouting, @unchecked Sendable {
    
    private let eventTagSelectSceneBuilder: any EventDefaultTagSelectSceneBuiler
    private let eventDefaultNotificationTimeSceneBuilder: any EventNotificationDefaultTimeOptionSceneBuiler
    private let eventDefaultMapAppSceneBuilder: any EventDefaultMapAppSceneBuiler
    private let selectGoogleCalendarDialogSceneBuilder: any SelectGoogleCalendarDialogSceneBuiler
    
    init(
        eventTagSelectSceneBuilder: any EventDefaultTagSelectSceneBuiler,
        eventDefaultNotificationTimeSceneBuilder: any EventNotificationDefaultTimeOptionSceneBuiler,
        eventDefaultMapAppSceneBuilder: any EventDefaultMapAppSceneBuiler,
        selectGoogleCalendarDialogSceneBuilder: any SelectGoogleCalendarDialogSceneBuiler
    ) {
        self.eventTagSelectSceneBuilder = eventTagSelectSceneBuilder
        self.eventDefaultNotificationTimeSceneBuilder = eventDefaultNotificationTimeSceneBuilder
        self.eventDefaultMapAppSceneBuilder = eventDefaultMapAppSceneBuilder
        self.selectGoogleCalendarDialogSceneBuilder = selectGoogleCalendarDialogSceneBuilder
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
            let next = self.eventTagSelectSceneBuilder.makeEventDefaultTagSelectScene()
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

    func routeToSelectGoogleCalendars(accountId: String) {
        Task { @MainActor in
            let next = self.selectGoogleCalendarDialogSceneBuilder.makeSelectGoogleCalendarDialogScene(accountId: accountId)
            self.showBottomSlide(next)
        }
    }
}
