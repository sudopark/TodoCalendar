//
//  
//  AddEventScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/15/23.
//
//

import UIKit
import Scenes


// MARK: - AddEventScene Interactable & Listenable

protocol AddEventSceneInteractor:
    AnyObject, SelectEventRepeatOptionSceneListener, SelectEventTagSceneListener { }
//
//public protocol AddEventSceneListener: AnyObject { }

// MARK: - AddEventScene

protocol AddEventScene: Scene where Interactor == any AddEventSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol AddEventSceneBuiler: AnyObject {
    
    @MainActor
    func makeAddEventScene() -> any AddEventScene
}
