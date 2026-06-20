//
//  Scenes+AIAgent.swift
//  Scenes
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain


// MARK: - render state

public enum AIAgentCommandBadge: Equatable, Sendable {
    case processing
    case needConfirm
    case done
    case failed
}

public enum AIAgentEntryMode: Equatable, Sendable {
    case none
    case idle
    case voice
    case keyboard
    case command(AIAgentCommandBadge)
}

// MARK: - AIAgentScene

public protocol AIAgentSceneInteractor: AnyObject {
    func prepare()
    func enterVoiceInput()
    func enterKeyboardInput()
    func stopInput()
    func submit(_ text: String)
}

public protocol AIAgentScene: Scene where Interactor == any AIAgentSceneInteractor { }

// MARK: - Listener (coordinator → DayEventList), plain 메서드 콜

public protocol AIAgentSceneListener: AnyObject {
    func aiAgent(didChangeMode mode: AIAgentEntryMode)
    func aiAgent(didUpdateVoiceLevel level: Float)
    func aiAgent(didUpdateRecognizingText text: String)
    func aiAgentDidRequestKeyboardEntryAvailable()
}

// MARK: - inline component + builder

public struct AIAgentInlineComponent {
    public let interactor: any AIAgentSceneInteractor
    public init(interactor: any AIAgentSceneInteractor) {
        self.interactor = interactor
    }
}

public protocol AIAgentSceneBuilder: AnyObject {
    @MainActor
    func makeInlineComponent(listener: any AIAgentSceneListener) -> AIAgentInlineComponent
}
