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

protocol CalendarPaperSceneInteractor: AnyObject {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth)
}
//
//public protocol CalendarPaperSceneListener: AnyObject { }

// MARK: - CalendarPaperScene

protocol CalendarPaperScene: Scene where Interactor == CalendarPaperSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol CalendarPaperSceneBuiler: AnyObject {
    
    func makeCalendarPaperScene() -> any CalendarPaperScene
}
