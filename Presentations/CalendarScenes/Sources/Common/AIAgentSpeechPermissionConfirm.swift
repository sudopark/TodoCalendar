//
//  AIAgentSpeechPermissionConfirm.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Scenes
import Extensions


extension ConfirmDialogInfo {

    static func aiAgentSpeechPermissionDenied(
        confirmed: @escaping () -> Void
    ) -> ConfirmDialogInfo {
        return ConfirmDialogInfo()
            |> \.title .~ "aiAgent::speechPermissionDenied::title".localized()
            |> \.message .~ "aiAgent::speechPermissionDenied::message".localized()
            |> \.confirmText .~ "aiAgent::speechPermissionDenied::confirm".localized()
            |> \.confirmed .~ confirmed
    }
}
