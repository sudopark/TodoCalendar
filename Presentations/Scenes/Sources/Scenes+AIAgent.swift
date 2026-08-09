//
//  Scenes+AIAgent.swift
//  Scenes
//

import UIKit
import Domain


// MARK: - AIAgentCommandScene Interactable & Listenable

public protocol AIAgentCommandSceneInteractor: AnyObject { }


// MARK: - AIAgentCommandScene

public protocol AIAgentCommandScene: Scene where Interactor == any AIAgentCommandSceneInteractor { }


// MARK: - Builder

public protocol AIAgentCommandSceneBuilder: AnyObject {

    @MainActor
    func makeCommandScene() -> any AIAgentCommandScene
}


// MARK: - AIAgentKeyboardInputScene Interactable & Listenable

public protocol AIAgentKeyboardInputSceneInteractor: AnyObject { }


// MARK: - AIAgentKeyboardInputScene

public protocol AIAgentKeyboardInputScene: Scene where Interactor == any AIAgentKeyboardInputSceneInteractor { }


// MARK: - Builder

public protocol AIAgentKeyboardInputSceneBuilder: AnyObject {

    @MainActor
    func makeKeyboardInputScene() -> any AIAgentKeyboardInputScene
}


// MARK: - AIAgentImageCommandScene Interactable & Listenable

public protocol AIAgentImageCommandSceneInteractor: AnyObject { }


// MARK: - AIAgentImageCommandScene

public protocol AIAgentImageCommandScene: Scene where Interactor == any AIAgentImageCommandSceneInteractor { }


// MARK: - Builder

public protocol AIAgentImageCommandSceneBuilder: AnyObject {

    @MainActor
    func makeImageCommandScene(imageData: Data) -> any AIAgentImageCommandScene
}
