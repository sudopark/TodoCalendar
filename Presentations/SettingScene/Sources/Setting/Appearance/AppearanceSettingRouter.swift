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

final class AppearanceSettingRouter: BaseRouterImple, AppearanceSettingRouting, @unchecked Sendable {
    
    private let timeZoneSelectBuilder: any TimeZoneSelectSceneBuiler
    
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
    
    func routeToSelectTimeZone() {
        Task { @MainActor in
            let next = self.timeZoneSelectBuilder.makeTimeZoneSelectScene()
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
}
