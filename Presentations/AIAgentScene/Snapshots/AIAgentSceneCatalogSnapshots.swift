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
    private func commandStageView(
        _ theme: SnapshotTheme, commandState: AIAgentCommandState? = nil
    ) -> some View {
        let state = AIAgentCommandViewState()
        state.commandState = commandState ?? .done(
            command: "catalog.ai::command".catalogLocalized(),
            message: "catalog.ai::result".catalogLocalized()
        )
        state.usage = AIAgentUsage(input: 3200, output: 0, limit: 20000)
            |> \.creditsUsed .~ 3200
        state.userPlan = BillingUserPlan() |> \.planId .~ .standard
        return AIAgentCommandStageView()
            .environment(state)
            .environment(AIAgentCommandViewEventHandler())
            .environment(self.makeAppearance(theme))
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
            self.commandStageView(theme)
        }
    }
}


// MARK: - App Store 스샷용 시트 조각

/// 앱스토어 스샷 규격(iPhone 16 Pro Max)의 논리 너비가 440pt 다 — 393pt 로 찍으면 1179px 이라 1320px 캔버스에서 확대돼 뭉갠다.
extension AIAgentSceneCatalogSnapshots {

    /// 말하듯 적은 명령이 그대로 보이는 순간 — 빈 입력창보다 이 상태가 기능을 설명한다.
    @MainActor
    func test_storeAICommandProcessing() {
        captureSnapshotPair(
            named: "storeAICommandProcessing", layout: .fixed(width: 440, height: 300),
            snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            self.commandStageView(
                theme, commandState: .processing(command: "catalog.ai::command".catalogLocalized())
            )
        }
    }

    @MainActor
    func test_storeAICommandDone() {
        captureSnapshotPair(
            named: "storeAICommandDone", layout: .fixed(width: 440, height: 320),
            snapshotDirectory: catalogSnapshotDirectory()
        ) { theme in
            self.commandStageView(theme)
        }
    }
}
