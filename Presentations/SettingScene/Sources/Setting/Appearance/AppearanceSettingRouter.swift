//
//  
//  AppearanceSettingRouter.swift
//  SettingScene
//
//  Created by sudo.park on 12/3/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol AppearanceSettingRouting: Routing, Sendable {
    
    func attachSubScenes() -> (
        calenadar: CalendarAppearanceSettingInteractor?,
        eventOnCalendar: EventOnCalendarAppearanceSettingInteractor?,
        eventList: EventListAppearanceSettingInteractor?
    )
    func routeToSelectTimeZone()
}

// MARK: - Router

final class AppearanceSettingRouter: BaseRouterImple, AppearanceSettingRouting, @unchecked Sendable {
    
    private let timeZoneSelectBuilder: any TimeZoneSelectSceneBuiler
    weak var calendarInteractor: CalendarAppearanceSettingInteractor?
    weak var eventOnCalendarInteractor: EventOnCalendarAppearanceSettingInteractor?
    weak var eventListInteractor: EventListAppearanceSettingInteractor?
    
    init(timeZoneSelectBuilder: any TimeZoneSelectSceneBuiler) {
        self.timeZoneSelectBuilder = timeZoneSelectBuilder
    }
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        self.currentScene?.navigationController?.popViewController(animated: animate)
    }
}


extension AppearanceSettingRouter {
    
    private var currentScene: (any AppearanceSettingScene)? {
        self.scene as? (any AppearanceSettingScene)
    }
    
    // TODO: router implememnts
    
    func attachSubScenes() -> (
        calenadar: CalendarAppearanceSettingInteractor?,
        eventOnCalendar: EventOnCalendarAppearanceSettingInteractor?,
        eventList: EventListAppearanceSettingInteractor?
    ) {
        return (self.calendarInteractor, self.eventOnCalendarInteractor, self.eventListInteractor)
    }
    
    func routeToSelectTimeZone() {
        Task { @MainActor in
            let next = self.timeZoneSelectBuilder.makeTimeZoneSelectScene()
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
}
