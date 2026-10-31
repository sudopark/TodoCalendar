//
//  
//  EventNotificationDefaultTimeOptionScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 1/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import SceneInfra


// MARK: - EventNotificationDefaultTimeOptionScene Interactable & Listenable

protocol EventNotificationDefaultTimeOptionSceneInteractor: AnyObject { }
//
//public protocol EventNotificationDefaultTimeOptionSceneListener: AnyObject { }

// MARK: - EventNotificationDefaultTimeOptionScene

protocol EventNotificationDefaultTimeOptionScene: Scene where Interactor == any EventNotificationDefaultTimeOptionSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol EventNotificationDefaultTimeOptionSceneBuiler: AnyObject {
    
    @MainActor
    func makeEventNotificationDefaultTimeOptionScene(
        forAllDay: Bool
    ) -> any EventNotificationDefaultTimeOptionScene
}
