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
import TestDoubles
import Extensions

@testable import Domain


class AIAgentOrchestrationUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []
    private var stubCommand: StubAICommandUsecase!
    private var stubUsage: StubAIAgentUsageUsecase!
    private var stubSpeech: StubSpeechRecognizeUsecase!
    private var stubSync: StubEventSyncUsecase!

    private func makeUsecase(shouldFail: Bool = false) -> AIAgentOrchestrationUsecaseImple {
        self.stubCommand = .init()
        self.stubCommand.shouldFail = shouldFail
        self.stubUsage = .init()
        self.stubSpeech = .init()
        self.stubSync = .init()
        return AIAgentOrchestrationUsecaseImple(
            commandUsecase: self.stubCommand,
            usageUsecase: self.stubUsage,
            speechRecognizeUsecase: self.stubSpeech,
            eventSyncUsecase: self.stubSync
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

    private func makeUsecaseWithRestoredJob(_ job: AIJob) -> AIAgentOrchestrationUsecaseImple {
        let usecase = self.makeUsecase()
        self.stubCommand.stubRestoreJob = job
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
        case .canceled: return .canceled
        }
    }

    private func mutation(
        _ type: AIJobDataMutation.DataType,
        _ op: AIJobDataMutation.Operation = .created
    ) -> AIJobDataMutation {
        return AIJobDataMutation(dataType: type, operation: op)
    }

    private func doneResult(with mutations: [AIJobDataMutation]) -> AIJobResult {
        return .done(
            AIJobResult.DoneResult()
            |> \.text .~ "완료"
            |> \.mutations .~ mutations
        )
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

    // exp claim만 담은 JWT 형태 토큰 (base64url, 패딩 제거)
    private func makeToken(expOffset: TimeInterval) -> String {
        let exp = Date().addingTimeInterval(expOffset).timeIntervalSince1970
        let encode: ([String: Any]) -> String = { dict in
            let data = try! JSONSerialization.data(withJSONObject: dict)
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return "\(encode(["alg": "HS256"])).\(encode(["exp": exp])).sig"
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
        guard case .done(_, let message) = try #require(states.last) else { Issue.record("done 아님"); return }
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

    @Test func usecase_submit_whileConfirming_throws() throws {
        // given — 이미 confirm 처리 중 (진짜 busy 상태)
        let usecase = self.makeUsecaseInConfirm()
        // when - then — 처리 중이면 throw(거부)
        #expect(throws: (any Error).self) {
            try usecase.submit("새 명령")
        }
    }

    // 회귀: 키보드 입력(listening) 상태에서 submit이 busy로 씹히던 버그
    @Test func usecase_submit_whileKeyboardListening_entersProcessing() async throws {
        // given — 키보드 입력 진입해 .listening(.keyboard)
        let expect = expectConfirm("listening 상태 submit → processing → done")
        expect.count = 2
        var done = AIJobResult.DoneResult()
        done.text = "완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        usecase.reset()
        usecase.enterKeyboardInput()
        // when
        let states = try await self.outputs(expect, for: usecase.state.dropFirst()) {
            try? usecase.submit("회의 잡아줘")
        }
        // then — busy 거부 없이 processing부터 시작
        #expect(states.map(self.stateName) == ["processing", "done"])
        #expect(self.stubCommand.didProcessCommand == "회의 잡아줘")
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
        guard case .confirm(let command, let message, let action, _) = try #require(states.last) else { Issue.record("confirm 아님"); return }
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
        guard case .failed(_, let reason, _) = try #require(states.last) else { Issue.record("failed 아님"); return }
        #expect(reason == "이해하지 못했어요")
    }

    @Test func usecase_whenResultFailedWithDailyLimit_carriesErrorCode() async throws {
        // given
        let expect = expectConfirm("한도 초과 failed → errorCode 전달")
        expect.count = 2
        var fail = AIJobResult.FailResult()
        fail.reason = "오늘 사용량을 모두 썼어요"
        fail.errorCode = .dailyLimitExceeded
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.failed(fail)))
        usecase.reset()
        // when
        let states = try await self.outputs(expect, for: usecase.state.dropFirst()) {
            try? usecase.submit("회의 잡아줘")
        }
        // then
        guard case .failed(_, let reason, let errorCode) = try #require(states.last) else { Issue.record("failed 아님"); return }
        #expect(reason == "오늘 사용량을 모두 썼어요")
        #expect(errorCode == .dailyLimitExceeded)
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


// MARK: - confirm 만료

extension AIAgentOrchestrationUsecaseImpleTests {

    @Test func usecase_whenConfirmJob_expireTimeFromTokenExp() async throws {
        // given
        let expect = expectConfirm("confirm 상태에 token exp 기반 만료 시각 탑재")
        let usecase = self.makeUsecaseInConfirm(token: self.makeToken(expOffset: 100))
        // when
        let state = try await self.firstOutput(expect, for: usecase.state)
        // then
        guard case .confirm(_, _, _, let expireTime?) = state
        else { Issue.record("confirm 상태 아님 또는 expireTime 없음"); return }
        #expect(abs(expireTime.timeIntervalSinceNow - 100) < 2)
    }

    // 축1: usecase_whenTokenExpNotParsable_confirmWithoutExpireTime ⇢ exp 파싱 실패 시 만료 처리 없이 confirm 유지
    @Test func usecase_whenTokenExpNotParsable_confirmWithoutExpireTime() async throws {
        // given — "tk-1"은 JWT 형태가 아니라 exp 파싱 불가
        let expect = expectConfirm("exp 파싱 실패 시 만료 시각 불명(nil) confirm")
        let usecase = self.makeUsecaseInConfirm(token: "tk-1")
        // when
        let state = try await self.firstOutput(expect, for: usecase.state)
        // then
        guard case .confirm(_, _, _, let expireTime) = state
        else { Issue.record("confirm 상태 아님"); return }
        #expect(expireTime == nil)
    }

    // 축1: usecase_confirmWithoutExpireTime_processesNormally ⇢ 만료 시각 불명일 땐 confirm() 호출 시 만료 차단 없이 정상 진행
    @Test func usecase_confirmWithoutExpireTime_processesNormally() async throws {
        // given — exp 파싱 실패로 expireTime nil인 confirm 상태
        let expect = expectConfirm("confirm 진입")
        let usecase = self.makeUsecaseInConfirm(token: "tk-1")
        _ = try await self.firstOutput(expect, for: usecase.state)
        // when
        usecase.confirm()
        // then — 만료 검증 없이 그대로 진행
        #expect(self.stubCommand.didProcessConfirmToken == "tk-1")
    }

    // 축1: usecase_whenConfirmJobAlreadyExpired_emitsConfirmWithPastExpireTime ⇢ restore 등으로 exp가 이미 지난 confirm job도 상태 전이 없이 .confirm(과거 expireTime)으로 방출된다 — 만료는 UI/소비자가 파생
    @Test func usecase_whenConfirmJobAlreadyExpired_emitsConfirmWithPastExpireTime() async throws {
        // given — restore 등으로 exp가 이미 지난 confirm job 수신
        let expect = expectConfirm("이미 만료된 토큰이어도 .confirm 방출 + 과거 expireTime")
        let usecase = self.makeUsecaseInConfirm(token: self.makeToken(expOffset: -10))
        // when
        let state = try await self.firstOutput(expect, for: usecase.state)
        // then
        guard case .confirm(_, _, _, let expireTime?) = state
        else { Issue.record("confirm 상태 아님 또는 expireTime 없음"); return }
        #expect(expireTime < Date())
    }

    // 축1: usecase_confirmWhenExpirePassed_doesNotProcess ⇢ expireTime이 과거인 confirm 상태에서 confirm() 호출은 처리하지 않고 상태도 유지
    @Test func usecase_confirmWhenExpirePassed_doesNotProcess() async throws {
        // given
        let expect = expectConfirm("만료 exp의 confirm 상태")
        let usecase = self.makeUsecaseInConfirm(token: self.makeToken(expOffset: -10))
        _ = try await self.firstOutput(expect, for: usecase.state)
        // when
        usecase.confirm()
        // then — 처리 호출 없음 + 상태는 여전히 confirm(전이 없음). CurrentValueSubject라 재구독하면 현재값 replay
        #expect(self.stubCommand.didProcessConfirmToken == nil)
        let expectAfter = expectConfirm("confirm() 이후에도 상태는 그대로 confirm")
        let stateAfter = try await self.firstOutput(expectAfter, for: usecase.state)
        #expect(stateAfter.map(self.stateName) == "confirm")
    }

    // 축1: usecase_declineWhenExpirePassed_rejectsAndBecomesIdle ⇢ 만료된 confirm이라도 decline은 기존 reject + idle 경로 그대로 성립
    @Test func usecase_declineWhenExpirePassed_rejectsAndBecomesIdle() async throws {
        // given
        let expect = expectConfirm("만료 confirm 닫기 = reject + idle")
        expect.count = 2
        let usecase = self.makeUsecaseInConfirm(token: self.makeToken(expOffset: -10))
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.decline()
        }
        // then
        #expect(states.map { self.stateName($0) } == ["confirm", "idle"])
        #expect(self.stubCommand.didRejectParentJobId == "parent-job")
    }

    // 축1: usecase_handleJobStatusChanged_whenConfirmExpired_skipsRefresh ⇢ 만료된 confirm 상태에서 푸시가 와도 즉시 조회를 스킵한다(로컬 종료)
    @Test func usecase_handleJobStatusChanged_whenConfirmExpired_skipsRefresh() async throws {
        // given
        let expect = expectConfirm("만료 confirm 상태 진입")
        let usecase = self.makeUsecaseInConfirm(token: self.makeToken(expOffset: -10))
        _ = try await self.firstOutput(expect, for: usecase.state)
        // when
        usecase.handleJobStatusChanged("job-1")
        // then
        #expect(self.stubCommand.didRefreshJobStatusWith == nil)
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


// MARK: - reset은 진행 중 command를 중지한다

extension AIAgentOrchestrationUsecaseImpleTests {

    @Test func usecase_reset_cancelsOngoingCommandAndGoesIdle() async throws {
        // given
        let expect = expectConfirm("reset → cancel + idle")
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
        #expect(self.stubCommand.didCancelJobId == "job-1")
    }

    @Test func usecase_decline_rejectsButDoesNotCancelOngoing() async throws {
        // given — confirm 상태
        let expect = expectConfirm("decline → reject 호출, cancel은 없다")
        expect.count = 2
        let usecase = self.makeUsecaseInConfirm(token: "reject-tk")
        try await Task.sleep(for: .milliseconds(30))
        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.decline()
        }
        // then — reject은 가되 cancel(중지) API는 안 나간다
        #expect(states.last.map(self.stateName) == "idle")
        #expect(self.stubCommand.didRejectParentJobId == "parent-job")
        #expect(self.stubCommand.didCancelJobId == nil)  // decline은 cancelOngoing 호출 안 함
    }
}


// MARK: - 유저가 결과를 확인하면 미확인 요청 기록을 지운다

extension AIAgentOrchestrationUsecaseImpleTests {

    @Test func usecase_whenReset_clearProcessingCommand() async throws {
        // given
        var done = AIJobResult.DoneResult()
        done.text = "완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        try? usecase.submit("회의")
        try await Task.sleep(for: .milliseconds(30))

        // when
        usecase.reset()

        // then
        #expect(self.stubCommand.didClearProcessingCommand == true)
    }

    @Test func usecase_whenDecline_clearProcessingCommand() async throws {
        // given
        let usecase = self.makeUsecaseInConfirm(token: "reject-tk")
        try await Task.sleep(for: .milliseconds(30))

        // when
        usecase.decline()

        // then
        #expect(self.stubCommand.didClearProcessingCommand == true)
    }
}


// MARK: - job 종료 시 mutation 기반 event sync 트리거

// submit은 동기 흐름(Just 방출 → handleJobResult 즉시 실행)이라 submit 반환 시점에
// sync 트리거 판정이 끝나 있다. 별도 대기 없이 stubSync 호출을 관찰한다.
extension AIAgentOrchestrationUsecaseImpleTests {

    @Test("done 결과에 todo mutation이 있으면 sync를 1회 트리거한다")
    func usecase_whenDoneWithTodoMutation_triggersSyncOnce() async throws {
        // given
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(self.doneResult(with: [self.mutation(.todo)]))
        )
        // when
        try? usecase.submit("할 일 추가해줘")
        // then
        #expect(self.stubSync.didSyncRequested == true)
        #expect(self.stubSync.didSyncRequestedCount == 1)
    }

    @Test(
        "schedule/tag mutation도 sync를 트리거한다",
        arguments: [AIJobDataMutation.DataType.schedule, .tag]
    )
    func usecase_whenDoneWithSyncTargetMutation_triggersSync(
        _ type: AIJobDataMutation.DataType
    ) async throws {
        // given
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(self.doneResult(with: [self.mutation(type)]))
        )
        // when
        try? usecase.submit("명령")
        // then
        #expect(self.stubSync.didSyncRequested == true)
    }

    @Test("sync 대상·비대상 mutation이 섞여 있으면 sync를 트리거한다")
    func usecase_whenMixedMutation_triggersSync() async throws {
        // given — 한 액션이 done+todo 여러 mutation을 낼 수 있음 (예: complete → [{todo,updated},{done,created}])
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(self.doneResult(with: [
                self.mutation(.doneTodo), self.mutation(.todo, .updated)
            ]))
        )
        // when
        try? usecase.submit("완료 처리해줘")
        // then
        #expect(self.stubSync.didSyncRequested == true)
    }

    @Test("done/event_detail mutation만 있으면 sync를 트리거하지 않는다")
    func usecase_whenDoneWithNonSyncMutationOnly_doesNotTriggerSync() async throws {
        // given
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(self.doneResult(with: [
                self.mutation(.doneTodo), self.mutation(.eventDetail, .updated)
            ]))
        )
        // when
        try? usecase.submit("완료 처리해줘")
        // then
        #expect(self.stubSync.didSyncRequested == false)
    }

    @Test("mutation이 비어있으면 sync를 트리거하지 않는다 (조회 전용 커맨드)")
    func usecase_whenNoMutation_doesNotTriggerSync() async throws {
        // given
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(self.doneResult(with: [])))
        // when
        try? usecase.submit("오늘 일정 뭐 있어?")
        // then
        #expect(self.stubSync.didSyncRequested == false)
    }

    @Test("confirm 결과에 sync 대상 mutation이 있으면 sync를 트리거한다")
    func usecase_whenConfirmWithSyncTargetMutation_triggersSync() async throws {
        // given
        var confirm = AIJobResult.ConfirmResult()
        confirm.text = "정말 삭제할까요?"
        confirm.action = AIConfirmCommandAction() |> \.confirmToken .~ "tk-1"
        confirm.mutations = [self.mutation(.schedule, .deleted)]
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(.confirm(confirm), command: "일정 삭제해줘")
        )
        // when
        try? usecase.submit("일정 삭제해줘")
        // then
        #expect(self.stubSync.didSyncRequested == true)
    }

    @Test("failed 결과에 sync 대상 mutation이 있으면 sync를 트리거한다")
    func usecase_whenFailedWithSyncTargetMutation_triggersSync() async throws {
        // given
        var fail = AIJobResult.FailResult()
        fail.reason = "일부만 처리됨"
        fail.mutations = [self.mutation(.todo)]
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.failed(fail)))
        // when
        try? usecase.submit("여러 개 추가해줘")
        // then
        #expect(self.stubSync.didSyncRequested == true)
    }

    @Test("canceled 결과의 커밋된 mutation도 sync를 트리거한다")
    func usecase_whenCanceledWithMutation_triggersSync() async throws {
        // given
        let canceled = AIJobResult.canceled(
            AIJobResult.CanceledResult() |> \.mutations .~ [self.mutation(.todo)]
        )
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(canceled, status: .canceled)
        )
        // when
        try? usecase.submit("추가하다 중지")
        // then
        #expect(self.stubSync.didSyncRequested == true)
    }

    @Test("rejected 결과(직전 confirm의 커밋된 mutation)도 sync를 트리거한다")
    func usecase_whenRejectedWithPriorMutation_triggersSync() async throws {
        // given — REJECTED는 result에 직전 CONFIRM 객체가 남고, 그 mutations는 confirm 이전 커밋분
        var confirm = AIJobResult.ConfirmResult()
        confirm.action = AIConfirmCommandAction() |> \.confirmToken .~ "tk-1"
        confirm.mutations = [self.mutation(.schedule, .updated)]
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(.confirm(confirm), status: .rejected)
        )
        // when
        try? usecase.submit("여러 작업 후 거부")
        // then
        #expect(self.stubSync.didSyncRequested == true)
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
    var didCancelJobId: String?
    var didProcessConfirmToken: String?
    var didClearProcessingCommand: Bool = false

    func processCommand(_ commandText: String) -> AnyPublisher<AIJob, any Error> {
        self.didProcessCommand = commandText
        return self.jobPublisher(self.stubCommandJob)
    }
    func processConfirmCommand(_ action: AIConfirmCommandAction) -> AnyPublisher<AIJob, any Error> {
        self.didProcessConfirmToken = action.confirmToken
        return self.jobPublisher(self.stubConfirmJob)
    }
    func rejectConfirmCommand(_ action: AIConfirmCommandAction) {
        self.didRejectParentJobId = action.parentJobId
    }
    func cancelOngoingCommand(_ jobId: String) {
        self.didCancelJobId = jobId
    }
    func clearProcessingCommand() {
        self.didClearProcessingCommand = true
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
    var didRefreshJobStatusWith: String?
    func refreshJobStatus(_ jobId: String) {
        self.didRefreshJobStatusWith = jobId
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


// MARK: - 음성 → 키보드 전환

extension AIAgentOrchestrationUsecaseImpleTests {

    // 회귀: 음성 입력(.listening(.voice)) 중 키보드 전환이 guard isIdle에 씹혀
    // stopListening·상태 전환이 안 되던 버그. → .listening(.keyboard)로 정식 전환돼야 한다.
    @Test func usecase_enterKeyboardInput_fromVoice_switchesToKeyboardAndStopsSpeech() async throws {
        // given — 음성 입력 중 (.listening(.voice))
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        let expect = expectConfirm("voice → keyboard")
        // when
        let state = try await self.firstOutput(expect, for: usecase.state.dropFirst()) {
            usecase.enterKeyboardInput()
        }
        // then — .listening(.keyboard) 전환 + speech 정식 종료
        #expect(self.stubSpeech.didStopListening == true)
        if case .listening(.keyboard) = state {} else {
            Issue.record("expected listening(.keyboard), got \(String(describing: state))")
        }
    }

    // 회귀: 음성→키보드 전환 후 키보드 닫기(dismissByGesture=enterVoiceInput)로
    // 음성 복귀가 안 되던 버그. 전환이 no-op이라 상태가 .listening(.voice)로 stale하면
    // canEnterVoiceInput 가드에 막혀 재시작이 씹혔다.
    @Test func usecase_voiceToKeyboardThenBackToVoice_restartsSpeech() async throws {
        // given — 음성 입력 → 키보드 전환
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()          // .listening(.voice), startListening 1회
        usecase.enterKeyboardInput()       // .listening(.keyboard), stopListening
        let expect = expectConfirm("keyboard 닫기 → voice 복귀")
        // when — 키보드 시트 닫힘(dismissByGesture) → enterVoiceInput
        let state = try await self.firstOutput(expect, for: usecase.state.dropFirst()) {
            usecase.enterVoiceInput()
        }
        // then — .listening(.voice) 복귀 + speech 재시작 (2번째 start)
        #expect(self.stubSpeech.startListeningCount == 2)
        if case .listening(.voice) = state {} else {
            Issue.record("expected listening(.voice), got \(String(describing: state))")
        }
    }
}


// MARK: - 중지된 job이 남아있는 채로 재시작한 경우 (방어)

extension AIAgentOrchestrationUsecaseImpleTests {

    @Test("restore가 읽은 job이 CANCELED면 폴링을 더 돌지 않고 idle로 종결한다")
    func usecase_whenRestoredJobIsCanceled_backToIdle() async throws {
        // given
        let expect = expectConfirm("CANCELED 잔여 job 복원 시 idle 방출")
        let job = AIJob(jobId: "some_job") |> \.status .~ AIJob.Status.canceled
        let usecase = self.makeUsecaseWithRestoredJob(job)

        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.restoreIfNeeded()
        }

        // then
        #expect(states.map(self.stateName) == ["idle"])
    }
}


// MARK: - 외부 트리거로 즉시 조회

extension AIAgentOrchestrationUsecaseImpleTests {

    @Test("추적 중인 job의 상태 변경 푸시를 받으면 즉시 조회를 트리거한다")
    func usecase_whenPushReceivedForCurrentJob_triggerImmediateCheck() async throws {
        // given
        let expect = expectConfirm("processing 진입")
        let usecase = self.makeUsecaseWithCommandJob(
            AIJob(jobId: "some_job") |> \.status .~ AIJob.Status.running
        )
        let _ = try await self.firstOutput(expect, for: usecase.state) {
            try? usecase.submit("명령")
        }

        // when
        usecase.handleJobStatusChanged("some_job")

        // then
        #expect(self.stubCommand.didRefreshJobStatusWith == "some_job")
    }

    @Test("추적 중이 아닌 job의 푸시는 무시한다")
    func usecase_whenPushReceivedForOtherJob_ignore() async throws {
        // given
        let expect = expectConfirm("processing 진입")
        let usecase = self.makeUsecaseWithCommandJob(
            AIJob(jobId: "some_job") |> \.status .~ AIJob.Status.running
        )
        let _ = try await self.firstOutput(expect, for: usecase.state) {
            try? usecase.submit("명령")
        }

        // when
        usecase.handleJobStatusChanged("other_job")

        // then
        #expect(self.stubCommand.didRefreshJobStatusWith == nil)
    }

    @Test("처리 중인 job이 없으면 포그라운드 복귀 새로고침은 아무것도 하지 않는다")
    func usecase_whenNoProcessingJob_foregroundRefreshDoesNothing() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()

        // when
        usecase.refreshProcessingJobIfNeeded()

        // then
        #expect(self.stubCommand.didRefreshJobStatusWith == nil)
    }

    @Test("처리 중인 job이 있으면 포그라운드 복귀 시 즉시 조회를 트리거한다")
    func usecase_whenProcessingJobExists_foregroundRefreshTriggersCheck() async throws {
        // given
        let expect = expectConfirm("processing 진입")
        let usecase = self.makeUsecaseWithCommandJob(
            AIJob(jobId: "some_job") |> \.status .~ AIJob.Status.running
        )
        let _ = try await self.firstOutput(expect, for: usecase.state) {
            try? usecase.submit("명령")
        }

        // when
        usecase.refreshProcessingJobIfNeeded()

        // then
        #expect(self.stubCommand.didRefreshJobStatusWith == "some_job")
    }
}
