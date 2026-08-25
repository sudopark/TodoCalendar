//
//  AIAgentRouter.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Scenes


// MARK: - AIAgentRouting

protocol AIAgentRouting: Routing, Sendable { }


// MARK: - AIAgentRouter

final class AIAgentRouter: BaseRouterImple, AIAgentRouting, @unchecked Sendable { }
