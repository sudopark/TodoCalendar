//
//  
//  EventSettingScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//

import UIKit
import SceneInfra


// MARK: - EventSettingScene Interactable & Listenable

protocol EventSettingSceneInteractor: AnyObject { }
//
//public protocol EventSettingSceneListener: AnyObject { }

// MARK: - EventSettingScene

protocol EventSettingScene: Scene where Interactor == any EventSettingSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol EventSettingSceneBuiler: AnyObject {
    
    @MainActor
    func makeEventSettingScene() -> any EventSettingScene
}
