//
//  
//  AppearanceSettingScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 12/3/23.
//
//

import UIKit
import Scenes


// MARK: - AppearanceSettingScene Interactable & Listenable

protocol AppearanceSettingSceneInteractor: AnyObject { }
//
//public protocol AppearanceSettingSceneListener: AnyObject { }

// MARK: - AppearanceSettingScene

protocol AppearanceSettingScene: Scene where Interactor == any AppearanceSettingSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol AppearanceSettingSceneBuiler: AnyObject {
    
    @MainActor
    func makeAppearanceSettingScene() -> any AppearanceSettingScene
}
