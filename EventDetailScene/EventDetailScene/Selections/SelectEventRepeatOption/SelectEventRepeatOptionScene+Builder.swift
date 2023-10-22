//
//  
//  SelectEventRepeatOptionScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Domain
import Scenes


// MARK: - SelectEventRepeatOptionScene Interactable & Listenable

struct EventRepeatingTimeSelectResult {
    let text: String
    let repeating: EventRepeating
}

protocol SelectEventRepeatOptionSceneInteractor: AnyObject { }
//
protocol SelectEventRepeatOptionSceneListener: AnyObject {
    
    func selectEventRepeatOption(didSelect repeating: EventRepeatingTimeSelectResult)
    func selectEventRepeatOptionNotRepeat()
}

// MARK: - SelectEventRepeatOptionScene

protocol SelectEventRepeatOptionScene: Scene where Interactor == any SelectEventRepeatOptionSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol SelectEventRepeatOptionSceneBuiler: AnyObject {
    
    @MainActor
    func makeSelectEventRepeatOptionScene(
        startTime: Date,
        previousSelected repeating: EventRepeating?,
        listener: (any SelectEventRepeatOptionSceneListener)?
    ) -> any SelectEventRepeatOptionScene
}
