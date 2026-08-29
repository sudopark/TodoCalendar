//
//  SpyAIAgentCommandSceneListener.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Scenes


final class SpyAIAgentCommandSceneListener: AIAgentCommandSceneListener, @unchecked Sendable {

    var didRequestPaywall = false
    func aiAgentCommandDidRequestPaywall() {
        self.didRequestPaywall = true
    }
}
