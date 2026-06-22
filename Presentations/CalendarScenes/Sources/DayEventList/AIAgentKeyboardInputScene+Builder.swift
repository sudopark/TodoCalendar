//
//  AIAgentKeyboardInputScene+Builder.swift
//  CalendarScenes
//

import UIKit
import Scenes


// MARK: - AIAgentKeyboardInputScene Interactable & Listenable

protocol AIAgentKeyboardInputSceneInteractor: AnyObject { }

// MARK: - AIAgentKeyboardInputScene

protocol AIAgentKeyboardInputScene: Scene where Interactor == any AIAgentKeyboardInputSceneInteractor { }


// MARK: - Builder

protocol AIAgentKeyboardInputSceneBuilder: AnyObject {

    @MainActor
    func makeScene() -> any AIAgentKeyboardInputScene
}
