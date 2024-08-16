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
    func routeToFeedbackPost()
    func routeToAccountManage()
    func routeToSignIn()
    func openShare(link path: String)
}

// MARK: - Router

final class SettingItemListRouter: BaseRouterImple, SettingItemListRouting, @unchecked Sendable { 
    
    private let appearanceSceneBuilder: any AppearanceSettingSceneBuiler
    private let eventSettingSceneBuilder: any EventSettingSceneBuiler
    private let holidayListSceneBuilder: any HolidayListSceneBuiler
    private let memberSceneBuilder: any MemberSceneBuilder
    private let feedbackPostSceneBuiler: any FeedbackPostSceneBuiler
    
    init(
        appearanceSceneBuilder: any AppearanceSettingSceneBuiler,
        eventSettingSceneBuilder: any EventSettingSceneBuiler,
        holidayListSceneBuilder: any HolidayListSceneBuiler,
        memberSceneBuilder: any MemberSceneBuilder,
        feedbackPostSceneBuiler: any FeedbackPostSceneBuiler
    ) {
        self.appearanceSceneBuilder = appearanceSceneBuilder
        self.eventSettingSceneBuilder = eventSettingSceneBuilder
        self.holidayListSceneBuilder = holidayListSceneBuilder
        self.memberSceneBuilder = memberSceneBuilder
        self.feedbackPostSceneBuiler = feedbackPostSceneBuiler
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
    
    func routeToHolidaySetting() {
        
        Task { @MainActor in
            
            let next = self.holidayListSceneBuilder.makeHolidayListScene()
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
    
    func routeToFeedbackPost() {
        Task { @MainActor in
            let next = self.feedbackPostSceneBuiler.makeFeedbackPostScene()
            self.currentScene?.present(next, animated: true)
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
    
    func openShare(link path: String) {
        Task { @MainActor in
            guard let url = URL(string: path) else { return }
            let shareItems: [Any] = [
                "To-do Calendar" as Any,
                url as Any
            ]
            let activityViewController = UIActivityViewController(
                activityItems: shareItems,
                applicationActivities: nil
            )
            activityViewController.popoverPresentationController?.sourceView = self.currentScene?.view
            self.currentScene?.present(activityViewController, animated: true)
        }
    }
}
