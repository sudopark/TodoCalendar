//
//  
//  EventTimeSelectionScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/17/23.
//
//

import UIKit
import Domain
import Scenes


// MARK: - EventTimeSelectionScene Interactable & Listenable

protocol EventTimeSelectionSceneInteractor: AnyObject { }

 protocol EventTimeSelectionSceneListener: AnyObject { 
     
     func eventTimeSelect(didSelect time: EventTime?)
 }

// MARK: - EventTimeSelectionScene

protocol EventTimeSelectionScene: Scene where Interactor == any EventTimeSelectionSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol EventTimeSelectionSceneBuiler: AnyObject {
    
    @MainActor
    func makeEventTimeSelectionScene() -> any EventTimeSelectionScene
}
