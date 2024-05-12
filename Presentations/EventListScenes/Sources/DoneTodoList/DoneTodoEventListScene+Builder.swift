//
//  
//  DoneTodoEventListScene+Builder.swift
//  EventListScenes
//
//  Created by sudo.park on 5/11/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes


// MARK: - DoneTodoEventListScene Interactable & Listenable

protocol DoneTodoEventListSceneInteractor: AnyObject { }
//
//public protocol DoneTodoEventListSceneListener: AnyObject { }

// MARK: - DoneTodoEventListScene

protocol DoneTodoEventListScene: Scene where Interactor == any DoneTodoEventListSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol DoneTodoEventListSceneBuiler: AnyObject {
    
    @MainActor
    func makeDoneTodoEventListScene() -> any DoneTodoEventListScene
}
