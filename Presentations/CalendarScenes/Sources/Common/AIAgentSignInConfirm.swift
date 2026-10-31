//
//  AIAgentSignInConfirm.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/6/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Extensions
import SceneInfra


extension ConfirmDialogInfo {

    static func aiAgentNeedSignIn(
        confirmed: @escaping () -> Void
    ) -> ConfirmDialogInfo {
        return ConfirmDialogInfo()
            |> \.title .~ "aiAgent::needSignIn::title".localized()
            |> \.message .~ "aiAgent::needSignIn::message".localized()
            |> \.confirmed .~ confirmed
    }
}
