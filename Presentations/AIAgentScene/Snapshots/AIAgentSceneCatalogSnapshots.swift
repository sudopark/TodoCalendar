//
//  AIAgentSceneCatalogSnapshots.swift
//  AIAgentScene
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Prelude
import Optics
import Domain
import CommonPresentation
import SnapshotTestHelpKit

@testable import AIAgentScene


final class AIAgentSceneCatalogSnapshots: XCTestCase {

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#D6236A", default: "#088CDA")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        return ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
    }

    @MainActor
    func test_aiInput() {
        captureSnapshotPair(
            named: "aiInput", layout: .fixed(width: 393, height: 300), snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            AIAgentKeyboardInputContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandler: AIAgentKeyboardInputEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.usage = AIAgentUsage(input: 3200, output: 0, limit: 20000)
                    |> \.creditsUsed .~ 3200
                state.userPlan = BillingUserPlan() |> \.planId .~ .standard
            }
        }
    }

    @MainActor
    func test_aiResult() {
        captureSnapshotPair(
            named: "aiResult", layout: .fixed(width: 393, height: 320), snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            let state = AIAgentCommandViewState()
            state.commandState = .done(
                command: "Lunch with Sara on Friday at noon",
                message: "Added “Lunch with Sara” to Friday, March 13 at 12:00 PM."
            )
            state.usage = AIAgentUsage(input: 3200, output: 0, limit: 20000)
                |> \.creditsUsed .~ 3200
            state.userPlan = BillingUserPlan() |> \.planId .~ .standard
            return AIAgentCommandStageView()
                .environment(state)
                .environment(AIAgentCommandViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
}
