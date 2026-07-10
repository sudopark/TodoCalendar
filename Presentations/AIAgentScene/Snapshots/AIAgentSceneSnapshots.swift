//
//  AIAgentSceneSnapshots.swift
//  AIAgentScene
//
//  Created by sudo.park on 7/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import CommonPresentation
import SnapshotTestHelpKit

@testable import AIAgentScene


final class AIAgentSceneSnapshots: XCTestCase {

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        return ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
    }

    // AIAgentKeyboardInputView는 private — public interface인 ContainerView로 캡처 (기본 empty 상태)
    @MainActor
    func test_keyboardInput() {
        captureSnapshotPair(named: "keyboardInput", layout: .fullScreen) { theme in
            AIAgentKeyboardInputContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandler: AIAgentKeyboardInputEventHandler()
            )
        }
    }

    @MainActor
    func test_commandConfirm() {
        captureSnapshotPair(named: "commandConfirm", layout: .fullScreen) { theme in
            let state = AIAgentCommandViewState()
            state.commandState = .confirm(command: "일정 삭제", message: "정말 삭제할까요?")
            return AIAgentCommandStageView()
                .environment(state)
                .environment(AIAgentCommandViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
}
