//
//  
//  EventDefaultMapAppScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes


// MARK: - EventDefaultMapAppScene Interactable & Listenable

protocol EventDefaultMapAppSceneInteractor: AnyObject { }
//
//public protocol EventDefaultMapAppSceneListener: AnyObject { }

// MARK: - EventDefaultMapAppScene

protocol EventDefaultMapAppScene: Scene where Interactor == any EventDefaultMapAppSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol EventDefaultMapAppSceneBuiler: AnyObject {
    
    @MainActor
    func makeEventDefaultMapAppScene() -> any EventDefaultMapAppScene
}
