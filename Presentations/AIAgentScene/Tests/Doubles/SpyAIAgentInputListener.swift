//
//  SpyAIAgentInputListener.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 6/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

@testable import AIAgentScene


final class SpyAIAgentInputListener: AIAgentInputViewModelListener {

    var didCompleteText: String?
    func aiAgentInput(didComplete text: String) {
        self.didCompleteText = text
    }

    var didRequestSystemSetting = false
    func aiAgentInputRequestSystemSetting() {
        self.didRequestSystemSetting = true
    }

    var didFailError: (any Error)?
    func aiAgentInput(didFail error: any Error) {
        self.didFailError = error
    }
}


final class SpyAIAgentCommandListener: AIAgentCommandViewModelListener {

    var didRequestClose = false
    func aiAgentCommandRequestClose() {
        self.didRequestClose = true
    }
}
