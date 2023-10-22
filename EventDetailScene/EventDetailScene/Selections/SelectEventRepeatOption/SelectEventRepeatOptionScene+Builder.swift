//
//  
//  SelectEventRepeatOptionScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Scenes


// MARK: - SelectEventRepeatOptionScene Interactable & Listenable

protocol SelectEventRepeatOptionSceneInteractor: AnyObject { }
//
//public protocol SelectEventRepeatOptionSceneListener: AnyObject { }

// MARK: - SelectEventRepeatOptionScene

protocol SelectEventRepeatOptionScene: Scene where Interactor == any SelectEventRepeatOptionSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol SelectEventRepeatOptionSceneBuiler: AnyObject {
    
    @MainActor
    func makeSelectEventRepeatOptionScene() -> any SelectEventRepeatOptionScene
}
