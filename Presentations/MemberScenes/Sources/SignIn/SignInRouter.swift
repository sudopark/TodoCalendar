//
//  
//  SignInRouter.swift
//  MemberScenes
//
//  Created by sudo.park on 2/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SignInRouting: Routing, Sendable { }

// MARK: - Router

final class SignInRouter: BaseRouterImple, SignInRouting, @unchecked Sendable { }


extension SignInRouter {
    
    private var currentScene: (any SignInScene)? {
        self.scene as? (any SignInScene)
    }
    
    // TODO: router implememnts
}
