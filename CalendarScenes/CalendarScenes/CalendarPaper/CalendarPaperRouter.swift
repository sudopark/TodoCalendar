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
        (any MonthSceneInteractor)?, (any DayEventListSceneInteractor)?
    )?
}

// MARK: - Router

final class CalendarPaperRouter: BaseRouterImple, CalendarPaperRouting, @unchecked Sendable {
    
    private let monthSceneBuilder: any MonthSceneBuilder
    private let eventListSceneBuilder: any DayEventListSceneBuiler
    
    init(
        monthSceneBuilder: any MonthSceneBuilder,
        eventListSceneBuilder: any DayEventListSceneBuiler
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
        (any MonthSceneInteractor)?, (any DayEventListSceneInteractor)?
    )? {
        guard let current = self.currentScene else { return nil }
        
        let monthScene = self.monthSceneBuilder.makeMonthScene(
            month,
            listener: current.interactor
        )
        let eventListScene = self.eventListSceneBuilder.makeDayEventListScene()
        
        current.addMonth(monthScene)
        current.addDayEventList(eventListScene)
        
        return (monthScene.interactor, eventListScene.interactor)
    }
}
