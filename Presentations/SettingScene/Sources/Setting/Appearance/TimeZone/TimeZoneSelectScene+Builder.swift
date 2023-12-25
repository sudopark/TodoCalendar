//
//  
//  TimeZoneSelectScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 12/25/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes


// MARK: - TimeZoneSelectScene Interactable & Listenable

protocol TimeZoneSelectSceneInteractor: AnyObject { }
//
//public protocol TimeZoneSelectSceneListener: AnyObject { }

// MARK: - TimeZoneSelectScene

protocol TimeZoneSelectScene: Scene where Interactor == any TimeZoneSelectSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol TimeZoneSelectSceneBuiler: AnyObject {
    
    @MainActor
    func makeTimeZoneSelectScene() -> any TimeZoneSelectScene
}
