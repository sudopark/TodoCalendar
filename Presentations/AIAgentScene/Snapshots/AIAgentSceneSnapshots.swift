//
//  AIAgentSceneSnapshots.swift
//  AIAgentScene
//
//  Created by sudo.park on 7/10/26.
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
            state.commandState = .confirm(
                command: "일정 삭제", message: "정말 삭제할까요?",
                expireTime: Date().addingTimeInterval(4 * 60 + 30)
            )
            state.usage = .init(input: 1234, output: 0, limit: 5000)
            return AIAgentCommandStageView()
                .environment(state)
                .environment(AIAgentCommandViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_commandConfirmExpired() {
        captureSnapshotPair(named: "commandConfirmExpired", layout: .fullScreen) { theme in
            let state = AIAgentCommandViewState()
            state.commandState = .confirm(
                command: "일정 삭제", message: "정말 삭제할까요?",
                expireTime: Date().addingTimeInterval(-10)
            )
            state.usage = .init(input: 1234, output: 0, limit: 5000)
            return AIAgentCommandStageView()
                .environment(state)
                .environment(AIAgentCommandViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_commandProcessing() {
        captureSnapshotPair(named: "commandProcessing", layout: .fullScreen) { theme in
            let state = AIAgentCommandViewState()
            state.commandState = .processing(command: "일정 삭제")
            state.usage = .init(input: 1234, output: 0, limit: 5000)
            return AIAgentCommandStageView()
                .environment(state)
                .environment(AIAgentCommandViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_commandDone() {
        captureSnapshotPair(named: "commandDone", layout: .fullScreen) { theme in
            let state = AIAgentCommandViewState()
            state.commandState = .done(command: "일정 삭제", message: "삭제를 완료했어요")
            state.usage = .init(input: 1234, output: 0, limit: 5000)
            return AIAgentCommandStageView()
                .environment(state)
                .environment(AIAgentCommandViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    // 플랜 칩 + top-up 잔량 + 하향 예약이 전부 노출된 상태 (#720)
    @MainActor
    func test_commandDoneWithPlanInfo() {
        captureSnapshotPair(named: "commandDoneWithPlanInfo", layout: .fullScreen) { theme in
            let state = AIAgentCommandViewState()
            state.commandState = .done(command: "일정 추가", message: "추가했어요")
            state.usage = AIAgentUsage(input: 1234, output: 0, limit: 20000)
                |> \.creditsUsed .~ 1234
            state.userPlan = BillingUserPlan()
                |> \.planId .~ .standard
                |> \.topupRemaining .~ 12300
                |> \.scheduledChange .~ .init(
                    planId: .free, effectiveAt: Date(timeIntervalSince1970: 1787702400)
                )
            return AIAgentCommandStageView()
                .environment(state)
                .environment(AIAgentCommandViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_commandFailed() {
        captureSnapshotPair(named: "commandFailed", layout: .fullScreen) { theme in
            let state = AIAgentCommandViewState()
            state.commandState = .failed(command: "일정 삭제", reason: "네트워크 오류가 발생했어요", errorCode: nil)
            state.usage = .init(input: 1234, output: 0, limit: 5000)
            return AIAgentCommandStageView()
                .environment(state)
                .environment(AIAgentCommandViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_commandFailedDailyLimit() {
        captureSnapshotPair(named: "commandFailedDailyLimit", layout: .fullScreen) { theme in
            let state = AIAgentCommandViewState()
            state.commandState = .failed(command: "일정 삭제", reason: "오늘 사용량을 모두 썼어요. 내일 다시 시도해 주세요.", errorCode: .dailyLimitExceeded)
            state.usage = .init(input: 5000, output: 0, limit: 5000)
            state.isPaywallAvailable = true
            return AIAgentCommandStageView()
                .environment(state)
                .environment(AIAgentCommandViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
}
