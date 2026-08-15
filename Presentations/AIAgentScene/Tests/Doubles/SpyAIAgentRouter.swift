//
//  SpyAIAgentRouter.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Scenes
import TestDoubles

@testable import AIAgentScene


final class SpyAIAgentRouter: BaseSpyRouter, AIAgentRouting, @unchecked Sendable {

    var didOpenSystemSetting = false
    func openSystemSetting() {
        self.didOpenSystemSetting = true
    }
}
