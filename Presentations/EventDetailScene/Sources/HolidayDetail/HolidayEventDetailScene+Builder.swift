//
//  
//  HolidayEventDetailScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes


// MARK: - HolidayEventDetailScene Interactable & Listenable

protocol HolidayEventDetailSceneInteractor: AnyObject { }
//
//public protocol HolidayEventDetailSceneListener: AnyObject { }

// MARK: - HolidayEventDetailScene

protocol HolidayEventDetailScene: Scene where Interactor == any HolidayEventDetailSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol HolidayEventDetailSceneBuiler: AnyObject {
    
    @MainActor
    func makeHolidayEventDetailScene(uuid: String) -> any HolidayEventDetailScene
}
