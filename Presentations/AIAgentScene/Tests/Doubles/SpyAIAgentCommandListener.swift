//
//  SpyAIAgentCommandListener.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 6/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

@testable import AIAgentScene


final class SpyAIAgentCommandListener: AIAgentCommandViewModelListener {

    var didRequestClose = false
    func aiAgentCommandRequestClose() {
        self.didRequestClose = true
    }
}
