//
//  
//  EventDefaultTagSelectScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 1/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes


// MARK: - EventDefaultTagSelectScene Interactable & Listenable

protocol EventDefaultTagSelectSceneInteractor: AnyObject { }
//
//public protocol EventDefaultTagSelectSceneListener: AnyObject { }

// MARK: - EventDefaultTagSelectScene

protocol EventDefaultTagSelectScene: Scene where Interactor == any EventDefaultTagSelectSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol EventDefaultTagSelectSceneBuiler: AnyObject {
    
    @MainActor
    func makeEventDefaultTagSelectScene() -> any EventDefaultTagSelectScene
}
