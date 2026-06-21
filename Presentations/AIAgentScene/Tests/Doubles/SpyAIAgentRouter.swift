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

    var didShowCommandSheet = false
    var didShowCommandSheetCount = 0
    var lastShownCommandViewModel: (any AIAgentCommandViewModel)?
    func showCommandSheet(_ viewModel: any AIAgentCommandViewModel) {
        self.didShowCommandSheet = true
        self.didShowCommandSheetCount += 1
        self.lastShownCommandViewModel = viewModel
    }

    var didDismissCommandSheet = false
    var didDismissCommandSheetCount = 0
    func dismissCommandSheet() {
        self.didDismissCommandSheet = true
        self.didDismissCommandSheetCount += 1
    }
}
