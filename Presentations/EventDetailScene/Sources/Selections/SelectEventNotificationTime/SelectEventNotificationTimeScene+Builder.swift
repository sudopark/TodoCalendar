//
//  
//  SelectEventNotificationTimeScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 1/31/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Domain
import Scenes


// MARK: - SelectEventNotificationTimeScene Interactable & Listenable

protocol SelectEventNotificationTimeSceneInteractor: AnyObject { }
//
public protocol SelectEventNotificationTimeSceneListener: AnyObject { 
    
    func selectEventNotificationTime(didUpdate selectedTimeOptions: [EventNotificationTimeOption])
}

// MARK: - SelectEventNotificationTimeScene

protocol SelectEventNotificationTimeScene: Scene where Interactor == any SelectEventNotificationTimeSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol SelectEventNotificationTimeSceneBuiler: AnyObject {
    
    @MainActor
    func makeSelectEventNotificationTimeScene(
        isForAllDay: Bool,
        startWith select: [EventNotificationTimeOption],
        eventTimeComponents: DateComponents,
        listener: (any SelectEventNotificationTimeSceneListener)?
    ) -> any SelectEventNotificationTimeScene
}
