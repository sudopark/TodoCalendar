//
//  
//  EventTagSelectScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 1/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes


// MARK: - EventTagSelectScene Interactable & Listenable

protocol EventTagSelectSceneInteractor: AnyObject { }
//
//public protocol EventTagSelectSceneListener: AnyObject { }

// MARK: - EventTagSelectScene

protocol EventTagSelectScene: Scene where Interactor == any EventTagSelectSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol EventTagSelectSceneBuiler: AnyObject {
    
    @MainActor
    func makeEventTagSelectScene() -> any EventTagSelectScene
}
