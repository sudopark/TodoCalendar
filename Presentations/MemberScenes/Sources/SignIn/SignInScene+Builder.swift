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


// MARK: - Builder + DependencyInjector Extension

protocol SignInSceneBuiler: AnyObject {
    
    @MainActor
    func makeSignInScene() -> any SignInScene
}
