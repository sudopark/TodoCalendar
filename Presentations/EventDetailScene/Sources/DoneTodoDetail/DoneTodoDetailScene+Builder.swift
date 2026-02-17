//
//  
//  DoneTodoDetailScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 2/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//
//

import UIKit
import Domain
import Scenes


// MARK: - DoneTodoDetailScene Interactable & Listenable

protocol DoneTodoDetailSceneInteractor: AnyObject { }
//
public protocol DoneTodoDetailSceneListener: AnyObject {
    
    func doneTodoDetail(revert doneTodoId: String, to todo: TodoEvent)
}

// MARK: - DoneTodoDetailScene

protocol DoneTodoDetailScene: Scene where Interactor == any DoneTodoDetailSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol DoneTodoDetailSceneBuiler: AnyObject {
    
    @MainActor
    func makeDoneTodoDetailScene(
        uuid: String,
        listener: (any DoneTodoDetailSceneListener)?
    ) -> any DoneTodoDetailScene
}
