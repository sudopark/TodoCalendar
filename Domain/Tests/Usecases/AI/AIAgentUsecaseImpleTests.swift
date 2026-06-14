//
//  AIAgentUsecaseImpleTests.swift
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


class AIAgentUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []
    private var stubCommand: StubAICommandUsecase!
    private var stubUsage: StubAIAgentUsageUsecase!

    private func makeUsecase(shouldFail: Bool = false) -> AIAgentUsecaseImple {
        self.stubCommand = .init()
        self.stubCommand.shouldFail = shouldFail
        self.stubUsage = .init()
        return AIAgentUsecaseImple(
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
        confirm.action = AIConfirmCommandAction()
            |> \.confirmToken .~ token
            |> \.parentJobId .~ "parent-job"
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(.confirm(confirm), command: command)
        )
        self.stubCommand.stubConfirmJob = job
        usecase.sendCommand(command)
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
        case .processing: return "processing"
        case .confirm: return "confirm"
        case .done: return "done"
        case .failed: return "failed"
        }
    }
}


// MARK: - 초기 상태 / usage

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

extension AIAgentUsecaseImpleTests {

    @Test func usecase_sendCommand_entersProcessingThenDone() async throws {
        // given
        let expect = expectConfirm("커맨드 전송 → processing → done")
        expect.count = 3
        var done = AIJobResult.DoneResult()
        done.text = "할 일 추가 완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.sendCommand("회의 잡아줘")
        }
        // then
        #expect(states.map(self.stateName) == ["idle", "processing", "done"])
        guard case .done(let message) = try #require(states.last) else { Issue.record("done 아님"); return }
        #expect(message == "할 일 추가 완료")
    }

    @Test func usecase_sendCommand_empty_isIgnored() async throws {
        // given
        let expect = expectConfirm("공백 커맨드 무시")
        let usecase = self.makeUsecase()
        // when
        let state = try await self.firstOutput(expect, for: usecase.state) {
            usecase.sendCommand("   ")
        }
        // then
        #expect(state.map(self.stateName) == "idle")
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
            usecase.sendCommand("내일 회의 잡아줘")
        }
        // then
        guard case .confirm(let command, let action) = try #require(states.last) else { Issue.record("confirm 아님"); return }
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
            usecase.sendCommand("뭐라고")
        }
        // then
        guard case .failed(let reason) = try #require(states.last) else { Issue.record("failed 아님"); return }
        #expect(reason == "이해하지 못했어요")
    }

    @Test func usecase_whenProcessingFails_entersFailed() async throws {
        // given
        let expect = expectConfirm("처리 에러 → failed")
        expect.count = 3
        let usecase = self.makeUsecase(shouldFail: true)
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.sendCommand("회의")
        }
        // then
        #expect(states.map(self.stateName).last == "failed")
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

extension AIAgentUsecaseImpleTests {

    @Test func usecase_reset_returnsToIdle() async throws {
        // given
        let expect = expectConfirm("초기화 → idle")
        expect.count = 2
        var done = AIJobResult.DoneResult()
        done.text = "완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        usecase.sendCommand("회의")
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
        expect.count = 2
        var done = AIJobResult.DoneResult()
        done.text = "완료"
        let usecase = self.makeUsecase()
        self.stubCommand.stubRestoreJob = self.dummyJob(.done(done))
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.restoreIfNeeded()
        }
        // then
        #expect(states.map(self.stateName) == ["idle", "done"])
    }

    @Test func usecase_restoreIfNeeded_whenNoInflightCommand_staysIdle() async throws {
        // given — 영속 job 없음 (restoreCommandifNeed → 무방출)
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
        expect.count = 2
        var confirm = AIJobResult.ConfirmResult()
        confirm.action = AIConfirmCommandAction() |> \.confirmToken .~ "tk-1"
        let rejectedJob = self.dummyJob(.confirm(confirm), status: .rejected)
        let usecase = self.makeUsecase()
        self.stubCommand.stubRestoreJob = rejectedJob
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.restoreIfNeeded()
        }
        // then — status 우선 판정으로 confirm 아닌 idle
        #expect(states.map(self.stateName) == ["idle", "idle"])
    }
}


// MARK: - test doubles

private final class StubAICommandUsecase: AICommandUsecase, @unchecked Sendable {

    var stubCommandJob: AIJob?
    var stubConfirmJob: AIJob?
    var stubRestoreJob: AIJob?
    var shouldFail: Bool = false
    var didRejectParentJobId: String?

    func processCommand(_ commandText: String) -> AnyPublisher<AIJob, any Error> {
        return self.jobPublisher(self.stubCommandJob)
    }
    func processConfirmCommand(_ action: AIConfirmCommandAction) -> AnyPublisher<AIJob, any Error> {
        return self.jobPublisher(self.stubConfirmJob)
    }
    func rejectConfirmCommand(_ action: AIConfirmCommandAction) {
        self.didRejectParentJobId = action.parentJobId
    }
    func restoreCommandifNeed() -> AnyPublisher<AIJob, any Error> {
        return self.jobPublisher(self.stubRestoreJob)
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
