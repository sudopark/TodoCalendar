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
    func attachCalendar() -> (any CalendarSceneInteractor)?
    
    func routeToEventTypeFilterSetting()
}

// MARK: - Router

final class MainRouter: BaseRouterImple, MainRouting, @unchecked Sendable {
    
    private let calendarSceneBulder: any CalendarSceneBuilder
    private let eventTagListSceneBuilder: any EventTagListSceneBuiler
    init(
        calendarSceneBulder: any CalendarSceneBuilder,
        eventTagListSceneBuilder: any EventTagListSceneBuiler
    ) {
        self.calendarSceneBulder = calendarSceneBulder
        self.eventTagListSceneBuilder = eventTagListSceneBuilder
    }
}


extension MainRouter {
    
    private var currentScene: (any MainScene)? {
        self.scene as? (any MainScene)
    }
    
    // TODO: router implememnts
    
    @MainActor
    func attachCalendar() -> (any CalendarSceneInteractor)? {
        guard let current = self.currentScene else { return nil }
        let calendarScene = self.calendarSceneBulder.makeCalendarScene(
            listener: current.interactor
        )
        current.addCalendar(calendarScene)
        
        return calendarScene.interactor
    }
    
    func routeToEventTypeFilterSetting() {
        Task { @MainActor in
            
            let eventSettingScene = self.eventTagListSceneBuilder.makeEventTagListScene(
                listener: nil
            )
            self.currentScene?.present(eventSettingScene, animated: true)
        }
    }
}
