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

protocol CalendarPaperSceneInteractor: AnyObject, MonthSceneListener {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth)
}
//
//public protocol CalendarPaperSceneListener: AnyObject { }

// MARK: - CalendarPaperScene

protocol CalendarPaperScene: Scene where Interactor == any CalendarPaperSceneInteractor
{
    
    @MainActor
    func addMonth(_ monthScene: any Scene)
    
    @MainActor
    func addDayEventList(_ eventListScene: any Scene)
}


// MARK: - Builder + DependencyInjector Extension

protocol CalendarPaperSceneBuiler: AnyObject {
    
    // TODO: month 삭제 예정
    @MainActor
    func makeCalendarPaperScene(_ month: CalendarMonth) -> any CalendarPaperScene
}
