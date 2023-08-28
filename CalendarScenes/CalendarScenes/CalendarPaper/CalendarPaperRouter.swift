//
//  
//  CalendarPaperRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol CalendarPaperRouting: Routing, Sendable {
    
    @MainActor
    func attachMonthAndEventList(_ month: CalendarMonth) -> (
        MonthSceneInteractor?, DayEventListSceneInteractor?
    )?
}

// MARK: - Router

final class CalendarPaperRouter: BaseRouterImple, CalendarPaperRouting, @unchecked Sendable {
    
    private let monthSceneBuilder: MonthSceneBuilder
    private let eventListSceneBuilder: DayEventListSceneBuiler
    
    init(
        monthSceneBuilder: MonthSceneBuilder,
        eventListSceneBuilder: DayEventListSceneBuiler
    ) {
        self.monthSceneBuilder = monthSceneBuilder
        self.eventListSceneBuilder = eventListSceneBuilder
    }
}


extension CalendarPaperRouter {
    
    private var currentScene: (any CalendarPaperScene)? {
        self.scene as? (any CalendarPaperScene)
    }
    
    // TODO: router implememnts
    @MainActor
    func attachMonthAndEventList(_ month: CalendarMonth) -> (
        MonthSceneInteractor?, DayEventListSceneInteractor?
    )? {
        guard let current = self.currentScene else { return nil }
        
        let monthScene = self.monthSceneBuilder.makeMonthScene(month)
        let eventListScene = self.eventListSceneBuilder.makeDayEventListScene()
        
        current.addMonth(monthScene)
        current.addDayEventList(eventListScene)
        
        return (monthScene.interactor, eventListScene.interactor)
    }
}
