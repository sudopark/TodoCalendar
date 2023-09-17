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

protocol DayEventListSceneInteractor: AnyObject {
    
    func selectedDayChanaged(
        _ newDay: CurrentSelectDayModel,
        and eventThatDay: [EventId]
    )
}
//
//public protocol DayEventListSceneListener: AnyObject { }

// MARK: - DayEventListScene

protocol DayEventListScene: Scene where Interactor == any DayEventListSceneInteractor
{
    
}


// MARK: - Builder + DependencyInjector Extension

protocol DayEventListSceneBuiler: AnyObject {
    
    func makeDayEventListScene() -> any DayEventListScene
}
