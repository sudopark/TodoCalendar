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
    
    func routeToSelectTimeZone()
}

// MARK: - Router

final class AppearanceSettingRouter: BaseRouterImple, AppearanceSettingRouting, CalendarSectionRouting, @unchecked Sendable {
    
    private let colorThemeSelectSceneBuiler: any ColorThemeSelectSceneBuiler
    private let timeZoneSelectBuilder: any TimeZoneSelectSceneBuiler
    
    init(
        colorThemeSelectSceneBuiler: any ColorThemeSelectSceneBuiler,
        timeZoneSelectBuilder: any TimeZoneSelectSceneBuiler
    ) {
        self.colorThemeSelectSceneBuiler = colorThemeSelectSceneBuiler
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
    
    func routeToSelectColorTheme() {
        Task { @MainActor in
            let next = self.colorThemeSelectSceneBuiler.makeColorThemeSelectScene()
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
    
    func routeToSelectTimeZone() {
        Task { @MainActor in
            let next = self.timeZoneSelectBuilder.makeTimeZoneSelectScene()
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
}
