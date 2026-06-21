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
    ) -> (AIAgentCoordinatorViewModelImple, StubAIAgentOrchestrationUsecase, StubSpeechRecognizeUsecase, SpyAIAgentRouter) {
        let stubOrchestration = StubAIAgentOrchestrationUsecase()
        if let initialState {
            stubOrchestration.stateSubject.send(initialState)
        }
        let stubSpeech = StubSpeechRecognizeUsecase()
        let coordinator = AIAgentCoordinatorViewModelImple(
            orchestrationUsecase: stubOrchestration,
            speechRecognizeUsecase: stubSpeech
        )
        let spyRouter = SpyAIAgentRouter()
        coordinator.router = spyRouter
        return (coordinator, stubOrchestration, stubSpeech, spyRouter)
    }
}


// MARK: - state → mode 통지

extension AIAgentCoordinatorViewModelImpleTests {

    @Test func coordinator_whenOrchestratorIdle_notifiesIdleMode() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _, _, _) = self.makeCoordinator(initialState: .idle)
        coordinator.listener = spy
        // when
        coordinator.prepare()
        // then
        #expect(spy.didChangedModes.contains(.idle))
    }

    @Test func coordinator_whenProcessing_notifiesProcessingBadge() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _, _, _) = self.makeCoordinator(initialState: .processing(command: "내일 회의"))
        coordinator.listener = spy
        // when
        coordinator.prepare()
        // then
        #expect(spy.didChangedModes.contains(.command(.processing)))
    }

    @Test func coordinator_whenConfirm_notifiesNeedConfirmBadge() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _, _, _) = self.makeCoordinator(
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
        let (coordinator, _, _, _) = self.makeCoordinator(initialState: .done(message: "완료"))
        coordinator.listener = spy
        // when
        coordinator.prepare()
        // then
        #expect(spy.didChangedModes.contains(.command(.done)))
    }

    @Test func coordinator_whenFailed_notifiesFailedBadge() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _, _, _) = self.makeCoordinator(initialState: .failed(reason: "오류"))
        coordinator.listener = spy
        // when
        coordinator.prepare()
        // then
        #expect(spy.didChangedModes.contains(.command(.failed)))
    }

    @Test func coordinator_whenStateChangesAfterPrepare_notifiesUpdatedMode() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, stubOrchestration, _, _) = self.makeCoordinator(initialState: .idle)
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
        let (coordinator, _, _, _) = self.makeCoordinator(initialState: nil)
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
        let (coordinator, stubOrchestration, _, _) = self.makeCoordinator()
        // when
        coordinator.prepare()
        // then
        #expect(stubOrchestration.didRestore == true)
    }

    @Test func coordinator_prepare_callsLoadUsage() {
        // given
        let (coordinator, stubOrchestration, _, _) = self.makeCoordinator()
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
        let (coordinator, stubOrchestration, _, _) = self.makeCoordinator()
        // when
        coordinator.submit("내일 회의 잡아줘")
        // then
        #expect(stubOrchestration.didSendCommand == "내일 회의 잡아줘")
    }
}


// MARK: - voice/keyboard input

extension AIAgentCoordinatorViewModelImpleTests {

    @Test func coordinator_enterVoiceInput_startsSpeechAndNotifiesVoiceMode() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _, stubSpeech, _) = self.makeCoordinator(initialState: .idle)
        coordinator.listener = spy
        coordinator.prepare()
        let modeCountBeforeVoice = spy.didChangedModes.count
        // when
        coordinator.enterVoiceInput()
        // then — speech started + .voice mode appended after prepare modes
        #expect(stubSpeech.didStartListening == true)
        let modesAfterEnter = Array(spy.didChangedModes.dropFirst(modeCountBeforeVoice))
        #expect(modesAfterEnter.contains(.voice))
    }

    @Test func coordinator_recognizingText_forwardsToListener() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _, stubSpeech, _) = self.makeCoordinator(initialState: .idle)
        coordinator.listener = spy
        coordinator.prepare()
        coordinator.enterVoiceInput()
        // when — Combine subjects are synchronous: send fires sink inline
        stubSpeech.recognizingTextSubject.send("오늘 회의")
        // then
        #expect(spy.didRecognizingTexts.contains("오늘 회의"))
    }

    @Test func coordinator_inputLevel_forwardsToListener() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _, stubSpeech, _) = self.makeCoordinator(initialState: .idle)
        coordinator.listener = spy
        coordinator.prepare()
        coordinator.enterVoiceInput()
        // when
        stubSpeech.levelSubject.send(0.75)
        // then
        #expect(spy.didVoiceLevels.contains(0.75))
    }

    @Test func coordinator_recognizeSuccess_sendsCommandToOrchestration() {
        // given
        let (coordinator, stubOrchestration, stubSpeech, _) = self.makeCoordinator(initialState: .idle)
        coordinator.listener = SpyAIAgentSceneListener()
        coordinator.prepare()
        coordinator.enterVoiceInput()
        // when
        stubSpeech.recognizeResultSubject.send(.success("내일 회의"))
        // then
        #expect(stubOrchestration.didSendCommand == "내일 회의")
    }

    @Test func coordinator_permissionDenied_notifiesKeyboardAvailableAndSwitchesToKeyboard() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _, stubSpeech, _) = self.makeCoordinator(initialState: .idle)
        coordinator.listener = spy
        coordinator.prepare()
        coordinator.enterVoiceInput()
        // when — permission denied error arrives
        let authError = SpeechRecognizeAuthError(micNotAvail: .denied)
        stubSpeech.recognizeResultSubject.send(.failure(authError))
        // then
        #expect(spy.didRequestedKeyboardAvailable == true)
        #expect(spy.didChangedModes.contains(.keyboard))
    }

    @Test func coordinator_enterKeyboardInput_stopsSpeechAndNotifiesKeyboardMode() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _, stubSpeech, _) = self.makeCoordinator(initialState: .idle)
        coordinator.listener = spy
        coordinator.prepare()
        coordinator.enterVoiceInput()
        let modeCountBeforeKeyboard = spy.didChangedModes.count
        // when
        coordinator.enterKeyboardInput()
        // then
        #expect(stubSpeech.didStopListening == true)
        let modesAfterKeyboard = Array(spy.didChangedModes.dropFirst(modeCountBeforeKeyboard))
        #expect(modesAfterKeyboard.contains(.keyboard))
    }

    @Test func coordinator_stopInput_stopsSpeechAndNotifiesIdleMode() {
        // given
        let spy = SpyAIAgentSceneListener()
        let (coordinator, _, stubSpeech, _) = self.makeCoordinator(initialState: .idle)
        coordinator.listener = spy
        coordinator.prepare()
        coordinator.enterVoiceInput()
        let modeCountBeforeStop = spy.didChangedModes.count
        // when
        coordinator.stopInput()
        // then
        #expect(stubSpeech.didStopListening == true)
        let modesAfterStop = Array(spy.didChangedModes.dropFirst(modeCountBeforeStop))
        #expect(modesAfterStop.contains(.idle))
    }

    @Test func coordinator_voiceInputThenOrchestrationProcessing_notifiesProcessingMode() {
        // given — orchestrator idle, enter voice
        let spy = SpyAIAgentSceneListener()
        let (coordinator, stubOrchestration, _, _) = self.makeCoordinator(initialState: .idle)
        coordinator.listener = spy
        coordinator.prepare()
        coordinator.enterVoiceInput()
        // when — orchestrator transitions to .processing
        stubOrchestration.stateSubject.send(.processing(command: "일정 추가"))
        // then — regardless of inputMode, orchestrator state takes priority
        #expect(spy.didChangedModes.last == .command(.processing))
    }

    @Test func coordinator_voiceRecognizeSuccess_sendsCommandAndTransitionsDirectlyToProcessing() {
        // given — voice 입력 중 상태
        let spy = SpyAIAgentSceneListener()
        let (coordinator, stubOrchestration, stubSpeech, _) = self.makeCoordinator(initialState: .idle)
        coordinator.listener = spy
        coordinator.prepare()
        coordinator.enterVoiceInput()
        let modeCountBeforeSuccess = spy.didChangedModes.count
        // when — speech recognize 성공 결과 방출 (stub이 sendCommand 시 .processing 방출)
        stubSpeech.recognizeResultSubject.send(.success("내일 회의"))
        // then (a) — sendCommand에 텍스트가 기록됨
        #expect(stubOrchestration.didSendCommand == "내일 회의")
        // then (b) — success 방출 이후 통지된 모드에 .idle 없고 마지막은 .command(.processing)
        let modesAfterSuccess = Array(spy.didChangedModes.dropFirst(modeCountBeforeSuccess))
        #expect(!modesAfterSuccess.contains(.idle))
        #expect(modesAfterSuccess.last == .command(.processing))
    }
}


// MARK: - command sheet routing

extension AIAgentCoordinatorViewModelImpleTests {

    @Test func coordinator_whenProcessingStateEmitted_showsCommandSheetOnce() {
        // given
        let (coordinator, stubOrchestration, _, spyRouter) = self.makeCoordinator(initialState: .idle)
        coordinator.prepare()
        // when
        stubOrchestration.stateSubject.send(.processing(command: "일정 추가"))
        // then — sheet는 첫 command 계열 진입 시 1회만 present
        #expect(spyRouter.didShowCommandSheet == true)
    }

    @Test func coordinator_whenProcessingThenConfirm_doesNotRepresentSheet() {
        // given
        let (coordinator, stubOrchestration, _, spyRouter) = self.makeCoordinator(initialState: .idle)
        coordinator.prepare()
        stubOrchestration.stateSubject.send(.processing(command: "일정 추가"))
        let showCountAfterProcessing = spyRouter.didShowCommandSheetCount
        // when — confirm 상태로 전환 (시트는 유지, 재표출 없음)
        stubOrchestration.stateSubject.send(
            .confirm(command: "일정 추가", message: "정말?", action: AIConfirmCommandAction())
        )
        // then
        #expect(spyRouter.didShowCommandSheetCount == showCountAfterProcessing)
    }

    @Test func coordinator_whenIdleAfterCommandSheet_dismissesSheet() {
        // given
        let (coordinator, stubOrchestration, _, spyRouter) = self.makeCoordinator(initialState: .idle)
        coordinator.prepare()
        stubOrchestration.stateSubject.send(.processing(command: "일정 추가"))
        // when — idle 복귀
        stubOrchestration.stateSubject.send(.idle)
        // then — 정확히 1회만 dismiss (중복 dismiss 방지)
        #expect(spyRouter.didDismissCommandSheetCount == 1)
    }

    @Test func coordinator_commandRequestClose_resetsOrchestration() {
        // given
        let (coordinator, stubOrchestration, _, _) = self.makeCoordinator(initialState: .idle)
        coordinator.prepare()
        stubOrchestration.stateSubject.send(.processing(command: "일정 추가"))
        // when — command VM이 close 요청
        coordinator.aiAgentCommandRequestClose()
        // then — orchestrationUsecase.reset() 호출
        #expect(stubOrchestration.didReset == true)
    }
}
