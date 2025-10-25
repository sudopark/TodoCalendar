//
//  
//  MainRouter.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/26.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol MainRouting: Routing, Sendable {
    
    @MainActor
    func attachCalendar() -> (any CalendarSceneInteractor)?
    
    func routeToEventTypeFilterSetting()
    func routeToSettingScene()
    func showJumpDaySelectDialog(current: CalendarDay)
}

// MARK: - Router

final class MainRouter: BaseRouterImple, MainRouting, @unchecked Sendable {
    
    private let calendarSceneBulder: any CalendarSceneBuilder
    private let settingSceneBuilder: any SettingSceneBuiler
    init(
        calendarSceneBulder: any CalendarSceneBuilder,
        settingSceneBuilder: any SettingSceneBuiler
    ) {
        self.calendarSceneBulder = calendarSceneBulder
        self.settingSceneBuilder = settingSceneBuilder
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
            
            let eventSettingScene = self.settingSceneBuilder.makeEventTagListScene(
                isRootNavigation: true,
                listener: nil
            )
            let navigationController = UINavigationController(rootViewController: eventSettingScene)
            self.currentScene?.present(navigationController, animated: true)
        }
    }
    
    func routeToSettingScene() {
        Task { @MainActor in
            
            let scene = self.settingSceneBuilder.makeSettingItemListScene()
            let navigation = UINavigationController(rootViewController: scene)
            self.currentScene?.present(navigation, animated: true)
        }
    }
    
    func showJumpDaySelectDialog(current: CalendarDay) {
        Task { @MainActor in
            
            let dialog = self.calendarSceneBulder.makeSelectDialog(
                current: current, self.currentScene?.interactor
            )
            self.showBottomSlide(dialog)
        }
    }
}
