//
//  
//  CalendarPaperScene+Builder.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Scenes
import Domain


// MARK: - CalendarPaperScene Interactable & Listenable

public protocol CalendarPaperSceneInteractor: AnyObject {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth)
}
//
//public protocol CalendarPaperSceneListener: AnyObject { }

// MARK: - CalendarPaperScene

public protocol CalendarPaperScene: Scene where Interactor == CalendarPaperSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

public protocol CalendarPaperSceneBuiler: AnyObject {
    
    func makeCalendarPaperScene() -> any CalendarPaperScene
}
