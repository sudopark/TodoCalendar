//
//  
//  MainScene+Builder.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/26.
//
//

import UIKit
import Scenes


// MARK: - MainScene Interactable & Listenable

public protocol MainSceneInteractor: Sendable, CalendarSceneListener { }
//
//public protocol MainSceneListener: AnyObject { }

// MARK: - MainScene

public protocol MainScene: Scene where Interactor == any MainSceneInteractor
{
    @MainActor
    func addCalendar(_ calendarScene: any CalendarScene)
}


// MARK: - Builder + DependencyInjector Extension

public protocol MainSceneBuiler: AnyObject {
    
    func makeMainScene() -> any MainScene
}
