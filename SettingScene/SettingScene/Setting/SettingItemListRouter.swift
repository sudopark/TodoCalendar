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
    
    func routeToHolidaySetting()
}

// MARK: - Router

final class SettingItemListRouter: BaseRouterImple, SettingItemListRouting, @unchecked Sendable { 
    
    private let holidayListSceneBuilder: any HolidayListSceneBuiler
    
    init(holidayListSceneBuilder: any HolidayListSceneBuiler) {
        self.holidayListSceneBuilder = holidayListSceneBuilder
    }
}


extension SettingItemListRouter {
    
    private var currentScene: (any SettingItemListScene)? {
        self.scene as? (any SettingItemListScene)
    }
    
    // TODO: router implememnts
    func routeToHolidaySetting() {
        
        Task { @MainActor in
            
            let next = self.holidayListSceneBuilder.makeHolidayListScene()
            self.currentScene?.navigationController?.navigationBar.isHidden = false
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
}
