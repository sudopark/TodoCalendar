//
//  AIAgentOrchestrationUsecaseImpleTests.swift
//  Domain
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Combine
import Prelude
import Optics
import UnitTestHelpKit
import Extensions

@testable import Domain


class AIAgentOrchestrationUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []
    private var stubCommand: StubAICommandUsecase!
    private var stubUsage: StubAIAgentUsageUsecase!
    private var stubSpeech: StubSpeechRecognizeUsecase!

    private func makeUsecase(shouldFail: Bool = false) -> AIAgentOrchestrationUsecaseImple {
        self.stubCommand = .init()
        self.stubCommand.shouldFail = shouldFail
        self.stubUsage = .init()
        self.stubSpeech = .init()
        return AIAgentOrchestrationUsecaseImple(
            commandUsecase: self.stubCommand,
            usageUsecase: self.stubUsage,
            speechRecognizeUsecase: self.stubSpeech
        )
    }

    private func makeUsecaseWithCommandJob(_ job: AIJob) -> AIAgentOrchestrationUsecaseImple {
        let usecase = self.makeUsecase()
        self.stubCommand.stubCommandJob = job
        return usecase
    }

    private func makeUsecaseInIdle() -> AIAgentOrchestrationUsecaseImple {
        let usecase = self.makeUsecase()
        usecase.reset()
        return usecase
    }

    private func makeUsecaseInConfirm(
        token: String = "tk-1",
        command: String = "내일 회의 잡아줘",
        confirmedBy job: AIJob? = nil
    ) -> AIAgentOrchestrationUsecaseImple {
        var confirm = AIJobResult.ConfirmResult()
        confirm.text = "정말 삭제할까요?"
        confirm.action = AIConfirmCommandAction()
            |> \.confirmToken .~ token
            |> \.parentJobId .~ "parent-job"
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(.confirm(confirm), command: command)
        )
        self.stubCommand.stubConfirmJob = job
        try? usecase.submit(command)
        return usecase
    }

    private func dummyJob(
        _ result: AIJobResult,
        command: String? = "회의 잡아줘",
        status: AIJob.Status? = nil
    ) -> AIJob {
        return AIJob(jobId: "job-1")
            |> \.command .~ command
            |> \.status .~ (status ?? self.status(for: result))
            |> \.result .~ result
    }

    private func status(for result: AIJobResult) -> AIJob.Status {
        switch result {
        case .done: return .done
        case .confirm: return .confirm
        case .failed: return .failed
        }
    }

    private func stateName(_ state: AIAgentState) -> String {
        switch state {
        case .idle: return "idle"
        case .listening(.voice): return "listening.voice"
        case .listening(.keyboard): return "listening.keyboard"
        case .listening: return "listening"
        case .processing: return "processing"
        case .confirm: return "confirm"
        case .done: return "done"
        case .failed: return "failed"
        }
    }
}


// MARK: - 초기 상태 / usage

extension AIAgentOrchestrationUsecaseImpleTests {

    @Test func usecase_initially_emitsNothingUntilStateDetermined() async throws {
        // given
        let usecase = self.makeUsecase()
        var emitted: [AIAgentState] = []
        // when — 구독만, 아무 동작 없음 (state 미확정 = 복원 중 같은 상황)
        let cancellable = usecase.state.sink { emitted.append($0) }
        // then — 확정 전이라 방출하지 않는다
        #expect(emitted.isEmpty)
        cancellable.cancel()
    }

    @Test func usecase_loadUsage_refreshesUsageUsecase() async throws {
        // given
        let usecase = self.makeUsecase()
        // when
        usecase.loadUsage()
        // then
        #expect(self.stubUsage.didRefresh == true)
    }

    @Test func usecase_usage_forwardsUsageUsecaseCurrentUsage() async throws {
        // given
        let expect = expectConfirm("usage 전달")
        let usecase = self.makeUsecase()
        let usage = AIAgentUsage(input: 10, output: 20, limit: 100)
        // when
        let output = try await self.firstOutput(expect, for: usecase.usage) {
            self.stubUsage.usageSubject.send(usage)
        }
        // then
        #expect(output?.dailyLimit == 100)
        #expect(output?.inputTokens == 10)
    }
}


// MARK: - 처리 시작 & 결과 분기

extension AIAgentOrchestrationUsecaseImpleTests {

    @Test func usecase_submit_entersProcessingThenDone() async throws {
        // given
        let expect = expectConfirm("커맨드 전송 → processing → done")
        expect.count = 2
        var done = AIJobResult.DoneResult()
        done.text = "할 일 추가 완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        usecase.reset()
        // when
        let states = try await self.outputs(expect, for: usecase.state.dropFirst()) {
            try? usecase.submit("회의 잡아줘")
        }
        // then — processing → done
        #expect(states.map(self.stateName) == ["processing", "done"])
        guard case .done(let message) = try #require(states.last) else { Issue.record("done 아님"); return }
        #expect(message == "할 일 추가 완료")
    }

    @Test func usecase_submit_empty_throws() throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        // when - then — 공백 입력은 throw
        #expect(throws: (any Error).self) {
            try usecase.submit("   ")
        }
    }

    @Test func usecase_submit_empty_doesNotProcessCommand() async throws {
        // given
        let expect = expectConfirm("공백 커맨드 무시")
        expect.count = 2
        var done = AIJobResult.DoneResult()
        done.text = "완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        usecase.reset()
        // when — 공백은 throw되고 유효 커맨드만 처리
        let states = try await self.outputs(expect, for: usecase.state.dropFirst()) {
            try? usecase.submit("   ")
            try? usecase.submit("회의")
        }
        // then — 공백 무시라 processing부터 시작
        #expect(states.map(self.stateName) == ["processing", "done"])
    }

    @Test func usecase_submit_whenNotIdle_throws() throws {
        // given — 이미 confirm 처리 중
        let usecase = self.makeUsecaseInConfirm()
        // when - then — idle이 아니면 throw(거부)
        #expect(throws: (any Error).self) {
            try usecase.submit("새 명령")
        }
    }

    @Test func usecase_whenResultConfirm_entersConfirmWithCommand() async throws {
        // given
        let expect = expectConfirm("결과 confirm → confirm 상태")
        expect.count = 2
        var confirm = AIJobResult.ConfirmResult()
        confirm.text = "정말 삭제할까요?"
        confirm.action = AIConfirmCommandAction() |> \.confirmToken .~ "tk-1"
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(.confirm(confirm), command: "내일 회의 잡아줘")
        )
        usecase.reset()
        // when
        let states = try await self.outputs(expect, for: usecase.state.dropFirst()) {
            try? usecase.submit("내일 회의 잡아줘")
        }
        // then
        guard case .confirm(let command, let message, let action) = try #require(states.last) else { Issue.record("confirm 아님"); return }
        #expect(command == "내일 회의 잡아줘")
        #expect(message == "정말 삭제할까요?")
        #expect(action.confirmToken == "tk-1")
    }

    @Test func usecase_whenResultFailed_entersFailed() async throws {
        // given
        let expect = expectConfirm("결과 failed → failed 상태")
        expect.count = 2
        var fail = AIJobResult.FailResult()
        fail.reason = "이해하지 못했어요"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.failed(fail)))
        usecase.reset()
        // when
        let states = try await self.outputs(expect, for: usecase.state.dropFirst()) {
            try? usecase.submit("뭐라고")
        }
        // then
        guard case .failed(let reason) = try #require(states.last) else { Issue.record("failed 아님"); return }
        #expect(reason == "이해하지 못했어요")
    }

    @Test func usecase_whenProcessingFails_entersFailed() async throws {
        // given
        let expect = expectConfirm("처리 에러 → failed")
        expect.count = 2
        let usecase = self.makeUsecase(shouldFail: true)
        usecase.reset()
        // when
        let states = try await self.outputs(expect, for: usecase.state.dropFirst()) {
            try? usecase.submit("회의")
        }
        // then
        #expect(states.map(self.stateName).last == "failed")
    }
}


// MARK: - confirm / decline

extension AIAgentOrchestrationUsecaseImpleTests {

    @Test func usecase_confirm_processesConfirmJobToDone() async throws {
        // given
        let expect = expectConfirm("동의 → confirm job 처리 → done")
        expect.count = 3
        var done = AIJobResult.DoneResult()
        done.text = "반영 완료"
        let usecase = self.makeUsecaseInConfirm(confirmedBy: self.dummyJob(.done(done)))
        try await Task.sleep(for: .milliseconds(30))
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.confirm()
        }
        // then — 구독 시 confirm 재방출 + processing + done
        #expect(states.map(self.stateName) == ["confirm", "processing", "done"])
    }

    @Test func usecase_decline_rejectsAndResetsToIdle() async throws {
        // given
        let expect = expectConfirm("미동의 → 거부 + idle 초기화")
        expect.count = 2
        let usecase = self.makeUsecaseInConfirm(token: "reject-tk")
        try await Task.sleep(for: .milliseconds(30))
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.decline()
        }
        // then
        #expect(states.last.map(self.stateName) == "idle")
        #expect(self.stubCommand.didRejectParentJobId == "parent-job")
    }
}


// MARK: - 초기화 / 복원

extension AIAgentOrchestrationUsecaseImpleTests {

    @Test func usecase_reset_returnsToIdle() async throws {
        // given
        let expect = expectConfirm("초기화 → idle")
        expect.count = 2
        var done = AIJobResult.DoneResult()
        done.text = "완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        usecase.reset()
        try? usecase.submit("회의")
        try await Task.sleep(for: .milliseconds(30))
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.reset()
        }
        // then
        #expect(states.last.map(self.stateName) == "idle")
    }

    @Test func usecase_restoreIfNeeded_attachesToInflightCommandAndEmitsResult() async throws {
        // given — 세션 종료 후 영속된 job이 done으로 끝나 있음 (서버 완료 + push 후 복귀)
        let expect = expectConfirm("복원 → 영속 in-flight job 결과 수신")
        var done = AIJobResult.DoneResult()
        done.text = "완료"
        let usecase = self.makeUsecase()
        self.stubCommand.stubRestoreJob = self.dummyJob(.done(done))
        // when
        let state = try await self.firstOutput(expect, for: usecase.state) {
            usecase.restoreIfNeeded()
        }
        // then — 복원된 job 결과만 방출 (idle 프리픽스 없음)
        #expect(state.map(self.stateName) == "done")
    }

    @Test func usecase_restoreIfNeeded_whenNoInflightCommand_staysIdle() async throws {
        // given — 영속 job 없음 (restoreCommandifNeed → nil 응답)
        let expect = expectConfirm("복원할 게 없으면 idle 유지")
        let usecase = self.makeUsecase()
        // when
        let state = try await self.firstOutput(expect, for: usecase.state) {
            usecase.restoreIfNeeded()
        }
        // then
        #expect(state.map(self.stateName) == "idle")
    }

    @Test func usecase_restoreIfNeeded_whenRejectedJob_staysIdleNotConfirm() async throws {
        // given — 이미 거부된 job (status=REJECTED, result.type=CONFIRM 보존) 복원
        let expect = expectConfirm("REJECTED 복원 → confirm 재노출 금지, idle")
        var confirm = AIJobResult.ConfirmResult()
        confirm.action = AIConfirmCommandAction() |> \.confirmToken .~ "tk-1"
        let rejectedJob = self.dummyJob(.confirm(confirm), status: .rejected)
        let usecase = self.makeUsecase()
        self.stubCommand.stubRestoreJob = rejectedJob
        // when
        let state = try await self.firstOutput(expect, for: usecase.state) {
            usecase.restoreIfNeeded()
        }
        // then — status 우선 판정으로 confirm 아닌 idle
        #expect(state.map(self.stateName) == "idle")
    }
}


// MARK: - test doubles

private final class StubAICommandUsecase: AICommandUsecase, @unchecked Sendable {

    var stubCommandJob: AIJob?
    var stubConfirmJob: AIJob?
    var stubRestoreJob: AIJob?
    var shouldFail: Bool = false
    var didRejectParentJobId: String?
    var didProcessCommand: String?
    var didRestore: Bool = false

    func processCommand(_ commandText: String) -> AnyPublisher<AIJob, any Error> {
        self.didProcessCommand = commandText
        return self.jobPublisher(self.stubCommandJob)
    }
    func processConfirmCommand(_ action: AIConfirmCommandAction) -> AnyPublisher<AIJob, any Error> {
        return self.jobPublisher(self.stubConfirmJob)
    }
    func rejectConfirmCommand(_ action: AIConfirmCommandAction) {
        self.didRejectParentJobId = action.parentJobId
    }
    func restoreCommandifNeed() -> AnyPublisher<AIJob?, any Error> {
        self.didRestore = true
        if self.shouldFail {
            return Fail(error: RuntimeError("stub fail")).eraseToAnyPublisher()
        }
        return Just(self.stubRestoreJob)
            .setFailureType(to: (any Error).self)
            .eraseToAnyPublisher()
    }
    func handleJobFinishNotification(_ jobId: String) { }

    private func jobPublisher(_ job: AIJob?) -> AnyPublisher<AIJob, any Error> {
        if self.shouldFail {
            return Fail(error: RuntimeError("stub fail")).eraseToAnyPublisher()
        }
        guard let job else { return Empty().eraseToAnyPublisher() }
        return Just(job).setFailureType(to: (any Error).self).eraseToAnyPublisher()
    }
}

private final class StubAIAgentUsageUsecase: AIAgentUsageUsecase, @unchecked Sendable {

    let usageSubject = CurrentValueSubject<AIAgentUsage?, Never>(nil)
    var didRefresh: Bool = false

    func refresh() { self.didRefresh = true }
    func loadUsage() async throws -> AIAgentUsage { throw RuntimeError("not imple") }
    var currentUsage: AnyPublisher<AIAgentUsage, Never> {
        return self.usageSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
}

private final class StubSpeechRecognizeUsecase: SpeechRecognizeUsecase, @unchecked Sendable {

    let recognizeResultSubject = PassthroughSubject<Result<String, any Error>, Never>()
    let recognizingTextSubject = CurrentValueSubject<String, Never>("")
    let levelSubject = CurrentValueSubject<Float?, Never>(nil)

    private(set) var didStartListening = false
    private(set) var didStopListening = false
    private(set) var didFinishListening = false
    private(set) var startListeningCount = 0

    func startListening() { self.didStartListening = true; self.startListeningCount += 1 }
    func stopListening() { self.didStopListening = true }
    func finishListening() { self.didFinishListening = true }

    var recognizeResult: AnyPublisher<Result<String, any Error>, Never> {
        self.recognizeResultSubject.eraseToAnyPublisher()
    }
    var recognizingText: AnyPublisher<String, Never> {
        self.recognizingTextSubject.eraseToAnyPublisher()
    }
    var isRecognizingWithLevel: AnyPublisher<Float?, Never> {
        self.levelSubject.eraseToAnyPublisher()
    }
}


// MARK: - 입력 제어 / listening 상태

extension AIAgentOrchestrationUsecaseImpleTests {

    // 입력 모드 → state.listening(.voice) + speech 시작
    @Test func usecase_enterVoiceInput_emitsListeningVoiceAndStartsSpeech() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        let expect = expectConfirm("listening(.voice)")
        // when
        let state = try await self.firstOutput(expect, for: usecase.state.dropFirst()) {
            usecase.enterVoiceInput()
        }
        // then
        #expect(self.stubSpeech.didStartListening == true)
        if case .listening(.voice) = state {} else {
            Issue.record("expected listening(.voice), got \(String(describing: state))")
        }
    }

    // recognizingText passthrough
    @Test func usecase_whileListening_forwardsRecognizingText() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        let expect = expectConfirm("recognizing text")
        // when
        let text = try await self.firstOutput(expect, for: usecase.recognizingText) {
            self.stubSpeech.recognizingTextSubject.send("오늘 회의")
        }
        // then
        #expect(text == "오늘 회의")
    }

    // 인식 성공 → idle → processing(command 보존)
    @Test func usecase_recognizeSuccess_sendsCommandAndProcessingState() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        let expect = expectConfirm("processing")
        expect.count = 2
        // when
        let states = try await self.outputs(expect, for: usecase.state.dropFirst()) {
            self.stubSpeech.recognizeResultSubject.send(.success("내일 회의"))
        }
        // then — listening → idle → processing
        #expect(self.stubCommand.didProcessCommand == "내일 회의")
        if case .processing(let c) = states.last {
            #expect(c == "내일 회의")
        } else {
            Issue.record("expected processing, got \(String(describing: states.last))")
        }
    }

    // 권한 거부 → state.idle (inputError 없음)
    @Test func usecase_permissionDenied_stateBecomesIdle() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        let expect = expectConfirm("idle on permission denied")
        // when
        let state = try await self.firstOutput(expect, for: usecase.state.dropFirst()) {
            self.stubSpeech.recognizeResultSubject.send(
                .failure(SpeechRecognizeAuthError(micNotAvail: .denied))
            )
        }
        // then
        if case .idle = state {} else {
            Issue.record("expected idle, got \(String(describing: state))")
        }
    }

    // 일반 인식 실패 → state.idle
    @Test func usecase_recognizeFailed_stateBecomesIdle() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        let expect = expectConfirm("idle on recognize fail")
        // when
        let state = try await self.firstOutput(expect, for: usecase.state.dropFirst()) {
            self.stubSpeech.recognizeResultSubject.send(.failure(RuntimeError("speech fail")))
        }
        // then
        if case .idle = state {} else {
            Issue.record("expected idle, got \(String(describing: state))")
        }
    }

    // stopInput → idle, speech stop
    @Test func usecase_stopInput_stopsSpeechAndIdle() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        let expect = expectConfirm("idle after stop")
        // when
        let state = try await self.firstOutput(expect, for: usecase.state.dropFirst()) {
            usecase.stopInput()
        }
        // then
        #expect(self.stubSpeech.didStopListening == true)
        if case .idle = state {} else {
            Issue.record("expected idle, got \(String(describing: state))")
        }
    }

    // enterKeyboardInput → listening(.keyboard)
    @Test func usecase_enterKeyboardInput_emitsListeningKeyboard() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        let expect = expectConfirm("listening(.keyboard)")
        // when
        let state = try await self.firstOutput(expect, for: usecase.state.dropFirst()) {
            usecase.enterKeyboardInput()
        }
        // then
        if case .listening(.keyboard) = state {} else {
            Issue.record("expected listening(.keyboard), got \(String(describing: state))")
        }
    }

    // finishVoiceInput → idle 전송 후 speech.finishListening
    @Test func usecase_finishVoiceInput_sendsIdleThenFinishesSpeech() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        let expect = expectConfirm("idle after finishVoiceInput")
        // when
        let state = try await self.firstOutput(expect, for: usecase.state.dropFirst()) {
            usecase.finishVoiceInput()
        }
        // then
        #expect(self.stubSpeech.didFinishListening == true)
        if case .idle = state {} else {
            Issue.record("expected idle, got \(String(describing: state))")
        }
    }

    // submit 빈 → throw, command 미전송
    @Test func usecase_submitEmpty_throwsAndDoesNotProcessCommand() throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        // when - then
        #expect(throws: (any Error).self) {
            try usecase.submit("")
        }
        #expect(self.stubCommand.didProcessCommand == nil)
    }

    // prepare → restore + loadUsage
    @Test func usecase_prepare_restoresAndLoadsUsage() async throws {
        // given
        let usecase = self.makeUsecase()
        // when
        usecase.prepare()
        // then
        #expect(self.stubCommand.didRestore == true)
        #expect(self.stubUsage.didRefresh == true)
    }
}


// MARK: - 키보드 → 음성 전환

extension AIAgentOrchestrationUsecaseImpleTests {

    // 키보드 입력 상태에서 enterVoiceInput → listening(.voice)로 전환
    @Test func usecase_enterVoiceInput_fromKeyboard_switchesToVoice() async throws {
        // given — reset() 후 enterKeyboardInput()으로 .listening(.keyboard) 진입
        let usecase = self.makeUsecase()
        usecase.reset()
        usecase.enterKeyboardInput()
        let expect = expectConfirm("keyboard → voice")
        // when
        let state = try await self.firstOutput(expect, for: usecase.state.dropFirst()) {
            usecase.enterVoiceInput()
        }
        // then — .listening(.voice) 전환 + speech 시작
        #expect(self.stubSpeech.didStartListening == true)
        if case .listening(.voice) = state {} else {
            Issue.record("expected listening(.voice), got \(String(describing: state))")
        }
    }

    // 이미 .listening(.voice) 상태에서 enterVoiceInput → no-op, speech 재시작 없음
    @Test func usecase_enterVoiceInput_alreadyVoice_isNoOp() async throws {
        // given — idle에서 enterVoiceInput으로 .listening(.voice)
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        // when — 이미 voice-listening 상태에서 재호출
        usecase.enterVoiceInput()
        // then — startListening은 첫 번째 한 번만 (두 번째 호출은 no-op)
        #expect(self.stubSpeech.startListeningCount == 1)
    }
}
