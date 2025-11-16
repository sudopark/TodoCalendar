//
//  
//  SelectMapAppDialogScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Domain
import Scenes


// MARK: - SelectMapAppDialogScene Interactable & Listenable

protocol SelectMapAppDialogSceneInteractor: AnyObject { }
//
//public protocol SelectMapAppDialogSceneListener: AnyObject { }

// MARK: - SelectMapAppDialogScene

protocol SelectMapAppDialogScene: Scene where Interactor == any SelectMapAppDialogSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol SelectMapAppDialogSceneBuiler: AnyObject {
    
    @MainActor
    func makeSelectMapAppDialogScene(
        query: String,
        supportMapApps: [SupportMapApps]
    ) -> any SelectMapAppDialogScene
}
