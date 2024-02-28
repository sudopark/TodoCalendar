//
//  Scenes+Member.swift
//  Scenes
//
//  Created by sudo.park on 2/29/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain

// MARK: - SignInScene Interactable & Listenable

public protocol SignInSceneInteractor: AnyObject { }
//
//public protocol SignInSceneListener: AnyObject { }

// MARK: - SignInScene

public protocol SignInScene: Scene where Interactor == any SignInSceneInteractor
{ }


public protocol MemberSceneBuilder {
    
    @MainActor
    func makeSignInScene() -> any SignInScene
}
