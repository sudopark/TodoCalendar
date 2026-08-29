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

    @MainActor
    func test_keyboardInput() {
        captureSnapshotPair(named: "keyboardInput", layout: .fullScreen) { theme in
            AIAgentKeyboardInputContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandler: AIAgentKeyboardInputEventHandler()
            )
        }
    }

    // 크레딧 소진 — 입력 시트에서도 게이지가 리셋까지 남은 시간을 함께 보여준다 (#763)
    @MainActor
    func test_keyboardInputLimitExceeded() {
        captureSnapshotPair(named: "keyboardInputLimitExceeded", layout: .fullScreen) { theme in
            AIAgentKeyboardInputContainerView(
                viewAppearance: self.makeAppearance(theme),
                eventHandler: AIAgentKeyboardInputEventHandler()
            )
            .eventHandler(\.stateBinding) { state in
                state.usage = AIAgentUsage(input: 5000, output: 0, limit: 5000)
                    |> \.resetsAt .~ Date().addingTimeInterval(3 * 3600 + 12 * 60 + 30)
                state.userPlan = BillingUserPlan() |> \.planId .~ .free
            }
        }
    }

    // expireTime 은 캡처 시각 기준 상대값 — 카운트다운(초 단위 올림)이 4:29 로 찍히도록
    // 268.9 초를 준다. 정수 경계(269)에서 0.9 초 떨어져 있어 렌더 지연이 그만큼 나도 표기가 안 바뀐다
    @MainActor
    func test_commandConfirm() {
        captureSnapshotPair(named: "commandConfirm", layout: .fullScreen) { theme in
            let state = AIAgentCommandViewState()
            state.commandState = .confirm(
                command: "일정 삭제", message: "정말 삭제할까요?",
                expireTime: Date().addingTimeInterval(4 * 60 + 28.9)
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

    // 한도 소진 — 게이지에 리셋까지 남은 시간이 함께 노출된다 (#763).
    // resetsAt 은 캡처 시각 기준 상대값, 오프셋에 30초 여유를 둬 렌더 지연으로 분 표기가 흔들리지 않게 한다
    @MainActor
    func test_commandFailedDailyLimit() {
        captureSnapshotPair(named: "commandFailedDailyLimit", layout: .fullScreen) { theme in
            let state = AIAgentCommandViewState()
            state.commandState = .failed(command: "일정 삭제", reason: "오늘 사용량을 모두 썼어요. 내일 다시 시도해 주세요.", errorCode: .dailyLimitExceeded)
            state.usage = AIAgentUsage(input: 5000, output: 0, limit: 5000)
                |> \.resetsAt .~ Date().addingTimeInterval(3 * 3600 + 12 * 60 + 30)
            state.userPlan = BillingUserPlan() |> \.planId .~ .free
            return AIAgentCommandStageView()
                .environment(state)
                .environment(AIAgentCommandViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }

    @MainActor
    func test_commandDoneMultilineMessage() {
        captureSnapshotPair(named: "commandDoneMultilineMessage", layout: .fullScreen) { theme in
            let state = AIAgentCommandViewState()
            state.commandState = .done(
                command: "이번 주 일정 정리해줘",
                message: AIAgentCommandStageViewPreviewProvider.sampleMultilineMessage
            )
            state.usage = .init(input: 1234, output: 0, limit: 5000)
            return AIAgentCommandStageView()
                .environment(state)
                .environment(AIAgentCommandViewEventHandler())
                .environment(self.makeAppearance(theme))
        }
    }
}
