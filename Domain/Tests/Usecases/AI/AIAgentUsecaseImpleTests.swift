//
//  AIAgentUsecaseImpleTests.swift
//  Domain
//
//  Created by sudo.park on 6/13/26.
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


class AIAgentUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []
    private var stubSpeech: StubSpeechUsecase!
    private var stubCommand: StubAICommandUsecase!
    private var stubUsage: StubAIAgentUsageUsecase!

    private func makeUsecase(shouldFail: Bool = false) -> AIAgentUsecaseImple {
        self.stubSpeech = .init()
        self.stubCommand = .init()
        self.stubCommand.shouldFail = shouldFail
        self.stubUsage = .init()
        return AIAgentUsecaseImple(
            speechUsecase: self.stubSpeech,
            commandUsecase: self.stubCommand,
            usageUsecase: self.stubUsage
        )
    }

    private func makeUsecaseWithCommandJob(_ job: AIJob) -> AIAgentUsecaseImple {
        let usecase = self.makeUsecase()
        self.stubCommand.stubCommandJob = job
        return usecase
    }

    private func makeUsecaseInConfirm(
        token: String = "tk-1",
        command: String = "내일 회의 잡아줘",
        confirmedBy job: AIJob? = nil
    ) -> AIAgentUsecaseImple {
        var confirm = AIJobResult.ConfirmResult()
        confirm.action = AIConfirmCommandAction() |> \.confirmToken .~ token
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(.confirm(confirm), command: command)
        )
        // confirm 동의 시 반환될 job을 생성 시점에 주입 (confirm()은 이후 호출됨)
        self.stubCommand.stubConfirmJob = job
        usecase.submitText(command)
        return usecase
    }

    private func dummyJob(_ result: AIJobResult, command: String? = "회의 잡아줘") -> AIJob {
        return AIJob(jobId: "job-1")
            |> \.command .~ command
            |> \.status .~ status(for: result)
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
        case .listening: return "listening"
        case .recognizing: return "recognizing"
        case .voicePermissionDenied: return "voicePermissionDenied"
        case .textInput: return "textInput"
        case .processing: return "processing"
        case .confirm: return "confirm"
        case .done: return "done"
        case .failed: return "failed"
        }
    }
}


// MARK: - 초기 상태

extension AIAgentUsecaseImpleTests {

    @Test func usecase_initialState_isIdle() async throws {
        // given
        let expect = expectConfirm("초기 상태 idle")
        let usecase = self.makeUsecase()
        // when
        let state = try await self.firstOutput(expect, for: usecase.state)
        // then
        #expect(state.map(self.stateName) == "idle")
    }

    @Test func usecase_loadUsage_refreshesUsageUsecase() async throws {
        // given
        let usecase = self.makeUsecase()
        // when
        usecase.loadUsage()
        // then
        #expect(self.stubUsage.didRefresh == true)
    }
}


// MARK: - 음성 입력

extension AIAgentUsecaseImpleTests {

    @Test func usecase_startVoiceInput_entersListeningAndStartsService() async throws {
        // given
        let expect = expectConfirm("음성 입력 시작 → listening")
        expect.count = 2
        let usecase = self.makeUsecase()
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.startVoiceInput()
        }
        // then
        #expect(states.map(self.stateName) == ["idle", "listening"])
        #expect(self.stubSpeech.didStartListening == true)
    }

    @Test func usecase_whenRecognizingTextEmitted_entersRecognizing() async throws {
        // given
        let expect = expectConfirm("실시간 텍스트 → recognizing")
        expect.count = 4
        let usecase = self.makeUsecase()
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.startVoiceInput()
            try await Task.sleep(for: .milliseconds(20))
            self.stubSpeech.levelSubject.send(0.4)
            self.stubSpeech.textSubject.send("회의 잡아")
        }
        // then
        let last = try #require(states.last)
        guard case .recognizing(let text, _) = last else {
            Issue.record("recognizing 상태가 아님"); return
        }
        #expect(text == "회의 잡아")
    }

    @Test func usecase_whenPermissionDenied_entersVoicePermissionDenied() async throws {
        // given
        let expect = expectConfirm("권한 거부 → voicePermissionDenied")
        expect.count = 3
        let usecase = self.makeUsecase()
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.startVoiceInput()
            try await Task.sleep(for: .milliseconds(20))
            self.stubSpeech.resultSubject.send(
                .failure(SpeechRecognizeAuthError(micNotAvail: .denied))
            )
        }
        // then
        #expect(states.map(self.stateName).last == "voicePermissionDenied")
    }
}


// MARK: - 처리 시작 & 결과 분기

extension AIAgentUsecaseImpleTests {

    @Test func usecase_submitText_entersProcessingThenDone() async throws {
        // given
        let expect = expectConfirm("텍스트 전송 → processing → done")
        expect.count = 3
        var done = AIJobResult.DoneResult()
        done.text = "할 일 추가 완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.submitText("회의 잡아줘")
        }
        // then
        #expect(states.map(self.stateName) == ["idle", "processing", "done"])
        guard case .done(let message) = try #require(states.last) else {
            Issue.record("done 아님"); return
        }
        #expect(message == "할 일 추가 완료")
    }

    @Test func usecase_whenResultConfirm_entersConfirmWithCommand() async throws {
        // given
        let expect = expectConfirm("결과 confirm → confirm 상태")
        expect.count = 3
        var confirm = AIJobResult.ConfirmResult()
        confirm.action = AIConfirmCommandAction() |> \.confirmToken .~ "tk-1"
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(.confirm(confirm), command: "내일 회의 잡아줘")
        )
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.submitText("내일 회의 잡아줘")
        }
        // then
        guard case .confirm(let command, let action) = try #require(states.last) else {
            Issue.record("confirm 아님"); return
        }
        #expect(command == "내일 회의 잡아줘")
        #expect(action.confirmToken == "tk-1")
    }

    @Test func usecase_whenResultFailed_entersFailed() async throws {
        // given
        let expect = expectConfirm("결과 failed → failed 상태")
        expect.count = 3
        var fail = AIJobResult.FailResult()
        fail.reason = "이해하지 못했어요"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.failed(fail)))
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.submitText("뭐라고")
        }
        // then
        guard case .failed(let reason) = try #require(states.last) else {
            Issue.record("failed 아님"); return
        }
        #expect(reason == "이해하지 못했어요")
    }

    @Test func usecase_whenProcessingFails_entersFailed() async throws {
        // given
        let expect = expectConfirm("처리 에러 → failed")
        expect.count = 3
        let usecase = self.makeUsecase(shouldFail: true)
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.submitText("회의")
        }
        // then
        #expect(states.map(self.stateName).last == "failed")
    }

    @Test func usecase_whenVoiceResultArrivesAfterProcessing_isIgnored() async throws {
        // given — submitText 후 processing 유지(stubCommandJob 없음 → Empty 완료, 상태 변화 없음)
        let expect = expectConfirm("처리 중 도착한 늦은 음성 결과 무시")
        expect.count = 2
        let usecase = self.makeUsecase()
        // when — processing 중에 음성 인식 성공이 뒤늦게 도착
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.submitText("회의")
            try await Task.sleep(for: .milliseconds(30))
            self.stubSpeech.resultSubject.send(.success("다른 말"))
            try await Task.sleep(for: .milliseconds(30))
        }
        // then — processing 그대로, 재처리/덮어쓰기 없음
        #expect(states.map(self.stateName) == ["idle", "processing"])
    }

    @Test func usecase_finishVoiceInput_callsFinishListening() async throws {
        // given
        let usecase = self.makeUsecase()
        usecase.startVoiceInput()
        // when
        usecase.finishVoiceInput()
        // then
        #expect(self.stubSpeech.didFinishListening == true)
    }
}


// MARK: - 초기화 / 전환 / 복원

extension AIAgentUsecaseImpleTests {

    @Test func usecase_switchToKeyboard_entersTextInputAndStopsListening() async throws {
        // given
        let expect = expectConfirm("키보드 전환 → textInput")
        expect.count = 2
        let usecase = self.makeUsecase()
        usecase.startVoiceInput()
        try await Task.sleep(for: .milliseconds(20))
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.switchToKeyboard()
        }
        // then
        #expect(states.last.map(self.stateName) == "textInput")
        #expect(self.stubSpeech.didStopListening == true)
    }

    @Test func usecase_reset_returnsToIdleAndStopsListening() async throws {
        // given
        let expect = expectConfirm("초기화 → idle")
        expect.count = 2
        let usecase = self.makeUsecase()
        usecase.startVoiceInput()
        try await Task.sleep(for: .milliseconds(20))
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.reset()
        }
        // then
        #expect(states.last.map(self.stateName) == "idle")
        #expect(self.stubSpeech.didStopListening == true)
    }

    @Test func usecase_restoreIfNeeded_reemitsCurrentState() async throws {
        // given
        let expect = expectConfirm("복원 → 현재 상태 재방출")
        expect.count = 2
        var done = AIJobResult.DoneResult()
        done.text = "완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        usecase.submitText("회의")
        try await Task.sleep(for: .milliseconds(30))
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.restoreIfNeeded()
        }
        // then
        #expect(states.last.map(self.stateName) == "done")
    }
}


// MARK: - confirm / decline

extension AIAgentUsecaseImpleTests {

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
        // then
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
        #expect(self.stubCommand.didRejectActionToken == "reject-tk")
    }
}


// MARK: - usage

extension AIAgentUsecaseImpleTests {

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


// MARK: - test doubles

private final class StubSpeechUsecase: SpeechRecognizeUsecase, @unchecked Sendable {

    let resultSubject = PassthroughSubject<Result<String, any Error>, Never>()
    let textSubject = CurrentValueSubject<String, Never>("")
    let levelSubject = CurrentValueSubject<Float?, Never>(nil)

    var didStartListening: Bool = false
    var didFinishListening: Bool = false
    var didStopListening: Bool = false

    func startListening() { self.didStartListening = true }
    func stopListening() { self.didStopListening = true }
    func finishListening() { self.didFinishListening = true }

    var recognizeResult: AnyPublisher<Result<String, any Error>, Never> {
        return self.resultSubject.eraseToAnyPublisher()
    }
    var recognizingText: AnyPublisher<String, Never> {
        return self.textSubject.eraseToAnyPublisher()
    }
    var isRecognizingWithLevel: AnyPublisher<Float?, Never> {
        return self.levelSubject.eraseToAnyPublisher()
    }
}

private final class StubAICommandUsecase: AICommandUsecase, @unchecked Sendable {

    var stubCommandJob: AIJob?
    var stubConfirmJob: AIJob?
    var shouldFail: Bool = false
    var didRejectActionToken: String?

    func processCommand(_ commandText: String) -> AnyPublisher<AIJob, any Error> {
        return self.jobPublisher(self.stubCommandJob)
    }
    func processConfirmCommand(_ action: AIConfirmCommandAction) -> AnyPublisher<AIJob, any Error> {
        return self.jobPublisher(self.stubConfirmJob)
    }
    func restoreCommandifNeed() -> AnyPublisher<AIJob, any Error> {
        return Empty().eraseToAnyPublisher()
    }
    func handleJobFinishNotification(_ jobId: String) { }
    func rejectConfirmCommand(_ action: AIConfirmCommandAction) {
        self.didRejectActionToken = action.confirmToken
    }

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
