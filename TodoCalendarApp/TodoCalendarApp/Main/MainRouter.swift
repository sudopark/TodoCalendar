//
//  
//  MainRouter.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/26.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol MainRouting: Routing, Sendable {
    
    @MainActor
    func attachCalendar() -> CalendarSceneInteractor?
}

// MARK: - Router

// TODO: compose next Scene Builders protocol
typealias MainNextSceneBuilders = CalendarSceneBuilder

final class MainRouter: BaseRouterImple<MainNextSceneBuilders>, MainRouting, @unchecked Sendable { }


extension MainRouter {
    
    private var currentScene: (any MainScene)? {
        self.scene as? (any MainScene)
    }
    
    // TODO: router implememnts
    
    @MainActor
    func attachCalendar() -> CalendarSceneInteractor? {
        guard let current = self.currentScene else { return nil }
        let calendarScene = self.nextScenesBuilder.makeCalendarScene(
            listener: current.interactor
        )
        current.addCalendar(calendarScene)
        
        return calendarScene.interactor
    }
}
