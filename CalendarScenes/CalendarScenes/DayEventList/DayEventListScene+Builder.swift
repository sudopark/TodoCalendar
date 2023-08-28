//
//  
//  DayEventListScene+Builder.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Scenes


// MARK: - DayEventListScene Interactable & Listenable

public protocol DayEventListSceneInteractor: AnyObject { }
//
//public protocol DayEventListSceneListener: AnyObject { }

// MARK: - DayEventListScene

public protocol DayEventListScene: Scene where Interactor == DayEventListSceneInteractor
{
    
}


// MARK: - Builder + DependencyInjector Extension

public protocol DayEventListSceneBuiler: AnyObject {
    
    func makeDayEventListScene() -> any DayEventListScene
}
