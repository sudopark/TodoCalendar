//
//  
//  FeedbackPostScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import SceneInfra


// MARK: - FeedbackPostScene Interactable & Listenable

protocol FeedbackPostSceneInteractor: AnyObject { }
//
//public protocol FeedbackPostSceneListener: AnyObject { }

// MARK: - FeedbackPostScene

protocol FeedbackPostScene: Scene where Interactor == any FeedbackPostSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol FeedbackPostSceneBuiler: AnyObject {
    
    @MainActor
    func makeFeedbackPostScene() -> any FeedbackPostScene
}
