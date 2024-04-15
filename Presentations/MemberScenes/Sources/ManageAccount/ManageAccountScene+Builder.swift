//
//  
//  ManageAccountScene+Builder.swift
//  MemberScenes
//
//  Created by sudo.park on 4/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes


// MARK: - ManageAccountScene Interactable & Listenable

protocol ManageAccountSceneInteractor: AnyObject { }
//
//public protocol ManageAccountSceneListener: AnyObject { }

// MARK: - ManageAccountScene

protocol ManageAccountScene: Scene where Interactor == any ManageAccountSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol ManageAccountSceneBuiler: AnyObject {
    
    @MainActor
    func makeManageAccountScene() -> any ManageAccountScene
}
