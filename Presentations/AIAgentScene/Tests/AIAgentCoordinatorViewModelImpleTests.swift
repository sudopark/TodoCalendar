//
//  AIAgentCoordinatorViewModelImpleTests.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 6/20/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Domain
import Scenes
import UnitTestHelpKit

@testable import AIAgentScene


// MARK: - SpyAIAgentSceneListener

final class SpyAIAgentSceneListener: AIAgentSceneListener {
    var didChangedModes: [AIAgentEntryMode] = []
    var didVoiceLevels: [Float] = []
    var didRecognizingTexts: [String] = []
    var didRequestedKeyboardAvailable: Bool = false

    func aiAgent(didChangeMode mode: AIAgentEntryMode) { self.didChangedModes.append(mode) }
    func aiAgent(didUpdateVoiceLevel level: Float) { self.didVoiceLevels.append(level) }
    func aiAgent(didUpdateRecognizingText text: String) { self.didRecognizingTexts.append(text) }
    func aiAgentDidRequestKeyboardEntryAvailable() { self.didRequestedKeyboardAvailable = true }
}


// MARK: - AIAgentCoordinatorViewModelImpleTests

final class AIAgentCoordinatorViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private func makeCoordinator(
        initialState: AIAgentState? = nil
    ) -> (AIAgentCoordinatorViewModelImple, StubAIAgentOrchestrationUsecase) {
        let stubOrchestration = StubAIAgentOrchestrationUsecase()
        if let initialState {
            stubOrchestration.stateSubject.send(initialState)
        }
        let stubSpeech = StubSpeechRecognizeUsecase()
        let coordinator = AIAgentCoordinatorViewModelImple(
            orchestrationUsecase: stubOrchestration,
            speechRecognizeUsecase: stubSpeech
        )
        return (coordinator, stubOrchestration)
    }
}


// MARK: - state → mode 통지

extension AIAgentCoordinatorViewModelImpleTests {

    @Test func coordinator_whenOrchestratorIdle_notifiesIdleMode() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _) = self.makeCoordinator(initialState: .idle)
        coordinator.listener = spy
        // when
        coordinator.prepare()
        // then
        #expect(spy.didChangedModes.contains(.idle))
    }

    @Test func coordinator_whenProcessing_notifiesProcessingBadge() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _) = self.makeCoordinator(initialState: .processing(command: "내일 회의"))
        coordinator.listener = spy
        // when
        coordinator.prepare()
        // then
        #expect(spy.didChangedModes.contains(.command(.processing)))
    }

    @Test func coordinator_whenConfirm_notifiesNeedConfirmBadge() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _) = self.makeCoordinator(
            initialState: .confirm(command: "삭제", message: "정말?", action: AIConfirmCommandAction())
        )
        coordinator.listener = spy
        // when
        coordinator.prepare()
        // then
        #expect(spy.didChangedModes.contains(.command(.needConfirm)))
    }

    @Test func coordinator_whenDone_notifiesDoneBadge() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _) = self.makeCoordinator(initialState: .done(message: "완료"))
        coordinator.listener = spy
        // when
        coordinator.prepare()
        // then
        #expect(spy.didChangedModes.contains(.command(.done)))
    }

    @Test func coordinator_whenFailed_notifiesFailedBadge() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _) = self.makeCoordinator(initialState: .failed(reason: "오류"))
        coordinator.listener = spy
        // when
        coordinator.prepare()
        // then
        #expect(spy.didChangedModes.contains(.command(.failed)))
    }

    @Test func coordinator_whenStateChangesAfterPrepare_notifiesUpdatedMode() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, stubOrchestration) = self.makeCoordinator(initialState: .idle)
        coordinator.listener = spy
        coordinator.prepare()
        // when
        stubOrchestration.stateSubject.send(.processing(command: "일정 추가"))
        // then
        #expect(spy.didChangedModes.contains(.idle))
        #expect(spy.didChangedModes.contains(.command(.processing)))
    }

    @Test func coordinator_beforeStateDetermined_doesNotNotify() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _) = self.makeCoordinator(initialState: nil)
        coordinator.listener = spy
        // when — orchestrator state 미확정 (nil)
        coordinator.prepare()
        // then — 아무 mode도 통지되지 않음
        #expect(spy.didChangedModes.isEmpty)
    }
}


// MARK: - prepare: usecase 호출

extension AIAgentCoordinatorViewModelImpleTests {

    @Test func coordinator_prepare_callsRestoreIfNeeded() {
        // given
        let (coordinator, stubOrchestration) = self.makeCoordinator()
        // when
        coordinator.prepare()
        // then
        #expect(stubOrchestration.didRestore == true)
    }

    @Test func coordinator_prepare_callsLoadUsage() {
        // given
        let (coordinator, stubOrchestration) = self.makeCoordinator()
        // when
        coordinator.prepare()
        // then
        #expect(stubOrchestration.didLoadUsage == true)
    }
}


// MARK: - submit

extension AIAgentCoordinatorViewModelImpleTests {

    @Test func coordinator_submit_delegatesToOrchestrationUsecase() {
        // given
        let (coordinator, stubOrchestration) = self.makeCoordinator()
        // when
        coordinator.submit("내일 회의 잡아줘")
        // then
        #expect(stubOrchestration.didSendCommand == "내일 회의 잡아줘")
    }
}
