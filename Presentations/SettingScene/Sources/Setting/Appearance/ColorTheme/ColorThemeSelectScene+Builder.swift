//
//  
//  ColorThemeSelectScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 8/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes


// MARK: - ColorThemeSelectScene Interactable & Listenable

protocol ColorThemeSelectSceneInteractor: AnyObject { }
//
//public protocol ColorThemeSelectSceneListener: AnyObject { }

// MARK: - ColorThemeSelectScene

protocol ColorThemeSelectScene: Scene where Interactor == any ColorThemeSelectSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol ColorThemeSelectSceneBuiler: AnyObject {
    
    @MainActor
    func makeColorThemeSelectScene() -> any ColorThemeSelectScene
}
