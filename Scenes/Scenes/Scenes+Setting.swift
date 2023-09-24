//
//  Scenes+Setting.swift
//  Scenes
//
//  Created by sudo.park on 2023/09/24.
//

import UIKit


// MARK: - EventTagListScene Interactable & Listenable

public protocol EventTagListSceneInteractor: AnyObject { }
//
//public protocol EventTagListSceneListener: AnyObject { }

// MARK: - EventTagListScene

public protocol EventTagListScene: Scene where Interactor == any EventTagListSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

public protocol EventTagListSceneBuiler: AnyObject {
    
    @MainActor
    func makeEventTagListScene() -> any EventTagListScene
}
