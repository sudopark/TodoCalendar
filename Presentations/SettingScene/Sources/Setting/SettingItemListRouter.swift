//
//  
//  SettingItemListRouter.swift
//  SettingScene
//
//  Created by sudo.park on 11/21/23.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SettingItemListRouting: Routing, Sendable { 
 
    func routeToAppearanceSetting(
        inital setting: CalendarAppearanceSettings
    )
    func routeToEventSetting()
    func routeToHolidaySetting()
    func routeToAccountManage()
    func routeToSignIn()
}

// MARK: - Router

final class SettingItemListRouter: BaseRouterImple, SettingItemListRouting, @unchecked Sendable { 
    
    private let appearanceSceneBuilder: any AppearanceSettingSceneBuiler
    private let eventSettingSceneBuilder: any EventSettingSceneBuiler
    private let holidayListSceneBuilder: any HolidayListSceneBuiler
    private let memberSceneBuilder: any MemberSceneBuilder
    
    init(
        appearanceSceneBuilder: any AppearanceSettingSceneBuiler,
        eventSettingSceneBuilder: any EventSettingSceneBuiler,
        holidayListSceneBuilder: any HolidayListSceneBuiler,
        memberSceneBuilder: any MemberSceneBuilder
    ) {
        self.appearanceSceneBuilder = appearanceSceneBuilder
        self.eventSettingSceneBuilder = eventSettingSceneBuilder
        self.holidayListSceneBuilder = holidayListSceneBuilder
        self.memberSceneBuilder = memberSceneBuilder
    }
}


extension SettingItemListRouter {
    
    private var currentScene: (any SettingItemListScene)? {
        self.scene as? (any SettingItemListScene)
    }
    
    func routeToAppearanceSetting(
        inital setting: CalendarAppearanceSettings
    ) {
        Task { @MainActor in
            
            let next = self.appearanceSceneBuilder.makeAppearanceSettingScene(
                inital: setting
            )
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
    
    func routeToEventSetting() {
        Task { @MainActor in
            let next = self.eventSettingSceneBuilder.makeEventSettingScene()
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
    
    func routeToAccountManage() {
        
        Task { @MainActor in
            
            let next = self.memberSceneBuilder.makeMangeAccountScene()
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
    
    func routeToSignIn() {
        Task { @MainActor in
            let next = self.memberSceneBuilder.makeSignInScene()
            self.currentScene?.present(next, animated: true)
        }
    }
}
