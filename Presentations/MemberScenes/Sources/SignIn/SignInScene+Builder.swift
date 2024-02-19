//
//  
//  SignInScene+Builder.swift
//  MemberScenes
//
//  Created by sudo.park on 2/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes


// MARK: - SignInScene Interactable & Listenable

protocol SignInSceneInteractor: AnyObject { }
//
//public protocol SignInSceneListener: AnyObject { }

// MARK: - SignInScene

protocol SignInScene: Scene where Interactor == any SignInSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol SignInSceneBuiler: AnyObject {
    
    @MainActor
    func makeSignInScene() -> any SignInScene
}
