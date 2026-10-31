//
//  AIAgentKeyboardInputRouter.swift
//  AIAgentScene
//

import Foundation
import SceneInfra


// MARK: - Routing

protocol AIAgentKeyboardInputRouting: Routing, Sendable { }


// MARK: - Router

final class AIAgentKeyboardInputRouter: BaseRouterImple, AIAgentKeyboardInputRouting, @unchecked Sendable { }
