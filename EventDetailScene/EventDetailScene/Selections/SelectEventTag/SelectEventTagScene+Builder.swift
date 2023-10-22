//
//  
//  SelectEventTagScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Scenes


// MARK: - SelectEventTagScene Interactable & Listenable

protocol SelectEventTagSceneInteractor: AnyObject { }
//
//public protocol SelectEventTagSceneListener: AnyObject { }

// MARK: - SelectEventTagScene

protocol SelectEventTagScene: Scene where Interactor == any SelectEventTagSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol SelectEventTagSceneBuiler: AnyObject {
    
    @MainActor
    func makeSelectEventTagScene() -> any SelectEventTagScene
}
