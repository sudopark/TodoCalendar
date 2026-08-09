//
//  AIAgentImageCommandRouter.swift
//  AIAgentScene
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Scenes


// MARK: - Routing

protocol AIAgentImageCommandRouting: Routing, Sendable { }


// MARK: - Router

final class AIAgentImageCommandRouter: BaseRouterImple, AIAgentImageCommandRouting, @unchecked Sendable { }
