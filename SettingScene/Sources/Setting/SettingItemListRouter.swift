//
//  
//  SettingItemListRouter.swift
//  SettingScene
//
//  Created by sudo.park on 11/21/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SettingItemListRouting: Routing, Sendable { 
 
    func routeToAppearanceSetting()
    func routeToHolidaySetting()
}

// MARK: - Router

final class SettingItemListRouter: BaseRouterImple, SettingItemListRouting, @unchecked Sendable { 
    
    private let appearanceSceneBuilder: any AppearanceSettingSceneBuiler
    private let holidayListSceneBuilder: any HolidayListSceneBuiler
    
    init(
        appearanceSceneBuilder: any AppearanceSettingSceneBuiler,
        holidayListSceneBuilder: any HolidayListSceneBuiler
    ) {
        self.appearanceSceneBuilder = appearanceSceneBuilder
        self.holidayListSceneBuilder = holidayListSceneBuilder
    }
}


extension SettingItemListRouter {
    
    private var currentScene: (any SettingItemListScene)? {
        self.scene as? (any SettingItemListScene)
    }
    
    func routeToAppearanceSetting() {
        Task { @MainActor in
            
            let next = self.appearanceSceneBuilder.makeAppearanceSettingScene()
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
    
    // TODO: router implememnts
    func routeToHolidaySetting() {
        
        Task { @MainActor in
            
            let next = self.holidayListSceneBuilder.makeHolidayListScene()
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
}
