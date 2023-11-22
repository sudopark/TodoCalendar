//
//  
//  SettingItemListScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 11/21/23.
//
//

import UIKit
import Scenes


// MARK: - SettingItemListScene Interactable & Listenable

protocol SettingItemListSceneInteractor: AnyObject { }
//
//public protocol SettingItemListSceneListener: AnyObject { }

// MARK: - SettingItemListScene

protocol SettingItemListScene: Scene where Interactor == any SettingItemListSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol SettingItemListSceneBuiler: AnyObject {
    
    @MainActor
    func makeSettingItemListScene() -> any SettingItemListScene
}
