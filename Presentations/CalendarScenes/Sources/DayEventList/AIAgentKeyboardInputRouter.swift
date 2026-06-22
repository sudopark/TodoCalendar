//
//  AIAgentKeyboardInputRouter.swift
//  CalendarScenes
//

import Foundation
import Scenes


// MARK: - Routing

protocol AIAgentKeyboardInputRouting: Routing, Sendable { }


// MARK: - Router

final class AIAgentKeyboardInputRouter: BaseRouterImple, AIAgentKeyboardInputRouting, @unchecked Sendable { }
