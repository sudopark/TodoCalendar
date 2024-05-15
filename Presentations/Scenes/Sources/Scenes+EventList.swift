//
//  Scenes+EventList.swift
//  Scenes
//
//  Created by sudo.park on 5/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


// MARK: - DoneTodoEventListScene Interactable & Listenable

public protocol DoneTodoEventListSceneInteractor: AnyObject { }
//
//public protocol DoneTodoEventListSceneListener: AnyObject { }

// MARK: - DoneTodoEventListScene

public protocol DoneTodoEventListScene: Scene where Interactor == any DoneTodoEventListSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

public protocol DoneTodoEventListSceneBuiler: AnyObject {
    
    @MainActor
    func makeDoneTodoEventListScene() -> any DoneTodoEventListScene
}


public protocol EventListSceneBuiler: DoneTodoEventListSceneBuiler { }
