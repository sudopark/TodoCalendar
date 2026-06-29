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
