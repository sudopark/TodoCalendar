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

    @Test func usecase_restoreIfNeeded_whenFailed_staysIdleNotFailed() async throws {
        // given — 복원 조회 자체가 실패 (로그아웃 직후 401 등)
        let expect = expectConfirm("복원 실패는 결과 화면 없이 idle")
        let usecase = self.makeUsecase(shouldFail: true)
        // when
        let state = try await self.firstOutput(expect, for: usecase.state) {
            usecase.restoreIfNeeded()
        }
        // then
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
        let usecase = self.makeUsecaseWithCommandJob(
            self.dummyJob(.done(done), status: .running)
        )
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

    // job 조회가 한 번도 안 끝난 시점 — 생성 응답의 started 이벤트로 받아둔 jobId로 중지한다
    @Test func usecase_reset_cancelsWithJobIdFromStartedEvent() async throws {
        // given — started만 방출되고 job은 아직 없다
        let usecase = self.makeUsecase()
        usecase.reset()
        try? usecase.submit("회의")
        try await Task.sleep(for: .milliseconds(30))

        // when
        usecase.reset()

        // then
        #expect(self.stubCommand.didCancelJobId == "job-1")
    }

    // 결과 확인(acknowledge)도 reset을 타는데, 이미 끝난 job에 취소가 나가면 안 된다
    @Test func usecase_whenJobFinished_resetDoesNotCancel() async throws {
        // given
        var done = AIJobResult.DoneResult()
        done.text = "완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        usecase.reset()
        try? usecase.submit("회의")
        try await Task.sleep(for: .milliseconds(30))

        // when
        usecase.reset()

        // then
        #expect(self.stubCommand.didCancelJobId == nil)
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

    func processCommand(_ commandText: String) -> AnyPublisher<AICommandProcessing, any Error> {
        self.didProcessCommand = commandText
        return self.processingPublisher(self.stubCommandJob)
    }

    private(set) var didProcessInterpretWith: (text: String, instruction: String?, source: AICommandInputSource)?
    func processInterpretCommand(
        text: String,
        additionalInstruction: String?,
        inputSource: AICommandInputSource
    ) -> AnyPublisher<AICommandProcessing, any Error> {
        self.didProcessInterpretWith = (text, additionalInstruction, inputSource)
        return self.processingPublisher(self.stubCommandJob)
    }

    func processConfirmCommand(_ action: AIConfirmCommandAction) -> AnyPublisher<AICommandProcessing, any Error> {
        self.didProcessConfirmToken = action.confirmToken
        return self.processingPublisher(self.stubConfirmJob)
    }
    func rejectConfirmCommand(_ action: AIConfirmCommandAction) {
        self.didRejectParentJobId = action.parentJobId
    }
    func cancelOngoingCommand(_ jobId: String) {
        self.didCancelJobId = jobId
    }
    func restoreCommandifNeed() -> AnyPublisher<AICommandProcessing?, any Error> {
        self.didRestore = true
        if self.shouldFail {
            return Fail(error: RuntimeError("stub fail")).eraseToAnyPublisher()
        }
        guard let job = self.stubRestoreJob else {
            return Just(nil).setFailureType(to: (any Error).self).eraseToAnyPublisher()
        }
        return [.started(jobId: job.jobId), .job(job)].publisher
            .map { Optional($0) }
            .setFailureType(to: (any Error).self)
            .eraseToAnyPublisher()
    }
    var didRefreshJobStatusWith: String?
    func refreshJobStatus(_ jobId: String) {
        self.didRefreshJobStatusWith = jobId
    }

    var didClearProcessingCommandRecord: Bool = false
    func clearProcessingCommandRecord() async {
        self.didClearProcessingCommandRecord = true
    }

    // 실물과 같은 순서로 방출한다 — 생성 응답(jobId)이 먼저, 조회된 job이 뒤
    var stubStartedJobId: String = "job-1"
    private func processingPublisher(_ job: AIJob?) -> AnyPublisher<AICommandProcessing, any Error> {
        if self.shouldFail {
            return Fail(error: RuntimeError("stub fail")).eraseToAnyPublisher()
        }
        let started = AICommandProcessing.started(jobId: self.stubStartedJobId)
        guard let job else {
            return Just(started).setFailureType(to: (any Error).self).eraseToAnyPublisher()
        }
        return [started, .job(job)].publisher
            .setFailureType(to: (any Error).self)
            .eraseToAnyPublisher()
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

    let recognizeResultSubject = PassthroughSubject<Result<SpeechRecognizeResult, any Error>, Never>()
    let recognizingTextSubject = CurrentValueSubject<String, Never>("")
    let levelSubject = CurrentValueSubject<Float?, Never>(nil)

    private(set) var didStartListening = false
    private(set) var didStopListening = false
    private(set) var didFinishListening = false
    private(set) var startListeningCount = 0

    func startListening() { self.didStartListening = true; self.startListeningCount += 1 }
    func stopListening() { self.didStopListening = true }
    func finishListening() { self.didFinishListening = true }

    var recognizeResult: AnyPublisher<Result<SpeechRecognizeResult, any Error>, Never> {
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
            self.stubSpeech.recognizeResultSubject.send(.success(.recognized("내일 회의")))
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

    // 침묵 타임아웃·오디오 끊김 등 무인식 종료 → idle 복귀 (커맨드 전송 없음)
    @Test func usecase_recognizeEndedWithoutText_stateBecomesIdle() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        let expect = expectConfirm("idle on ended without recognizing")
        // when
        let state = try await self.firstOutput(expect, for: usecase.state.dropFirst()) {
            self.stubSpeech.recognizeResultSubject.send(.success(.endedWithoutRecognizing))
        }
        // then
        if case .idle = state {} else {
            Issue.record("expected idle, got \(String(describing: state))")
        }
        #expect(self.stubCommand.didProcessCommand == nil)
    }

    // 무인식 종료 후 이전 음성 구독이 남지 않는다
    @Test func usecase_afterRecognizeEndedWithoutText_stopsForwardingRecognizingText() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        self.stubSpeech.recognizeResultSubject.send(.success(.endedWithoutRecognizing))
        let expect = expectConfirm("바인딩 해제 후 인식 텍스트 미전달")
        expect.count = 0
        expect.timeout = .milliseconds(100)
        // when
        let texts = try await self.outputs(expect, for: usecase.recognizingText) {
            self.stubSpeech.recognizingTextSubject.send("남은 구독이 흘리면 안 되는 텍스트")
        }
        // then
        #expect(texts.isEmpty)
    }

    // 인식 실패 후에도 이전 음성 구독이 남지 않는다
    @Test func usecase_afterRecognizeFailed_stopsForwardingRecognizingText() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        self.stubSpeech.recognizeResultSubject.send(.failure(RuntimeError("speech fail")))
        let expect = expectConfirm("실패 후 인식 텍스트 미전달")
        expect.count = 0
        expect.timeout = .milliseconds(100)
        // when
        let texts = try await self.outputs(expect, for: usecase.recognizingText) {
            self.stubSpeech.recognizingTextSubject.send("남은 구독이 흘리면 안 되는 텍스트")
        }
        // then
        #expect(texts.isEmpty)
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

    // 키보드 전환 후 이전 음성 구독이 남지 않는다
    @Test func usecase_afterEnterKeyboardInput_stopsForwardingRecognizingText() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        usecase.enterKeyboardInput()
        let expect = expectConfirm("키보드 전환 후 인식 텍스트 미전달")
        expect.count = 0
        expect.timeout = .milliseconds(100)
        // when
        let texts = try await self.outputs(expect, for: usecase.recognizingText) {
            self.stubSpeech.recognizingTextSubject.send("음성 잔여 텍스트")
        }
        // then
        #expect(texts.isEmpty)
    }

    // 뒤늦게 도착한 음성 종료가 키보드 입력 상태를 덮지 않는다
    @Test func usecase_lateRecognizeEndAfterEnterKeyboardInput_keepsKeyboardListening() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        usecase.enterKeyboardInput()
        let expect = expectConfirm("키보드 입력 상태 유지")
        expect.count = 0
        expect.timeout = .milliseconds(100)
        // when
        let states = try await self.outputs(expect, for: usecase.state.dropFirst()) {
            self.stubSpeech.recognizeResultSubject.send(.success(.endedWithoutRecognizing))
        }
        // then
        #expect(states.isEmpty)
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


// MARK: - 아직 진행 중인 job 복원

extension AIAgentOrchestrationUsecaseImpleTests {

    // 앱 밖(확장·인텐트)에서 만들어진 job은 복원 시점에 아직 running이다.
    // processing으로 올려야 유저가 진행 상태를 보고, 제출 가드도 이 job을 인지한다.
    @Test("복원한 job이 아직 진행 중이면 processing으로 올린다")
    func usecase_whenRestoredJobIsRunning_enterProcessing() async throws {
        // given
        let expect = expectConfirm("running 잔여 job 복원 시 processing 방출")
        let job = AIJob(jobId: "some_job")
            |> \.status .~ AIJob.Status.running
            |> \.command .~ "9월 10일 약속"
        let usecase = self.makeUsecaseWithRestoredJob(job)

        // when
        let states = try await self.outputs(expect, for: usecase.state) {
            usecase.restoreIfNeeded()
        }

        // then
        #expect(states.map(self.stateName) == ["processing"])
    }

    @Test("진행 중인 job을 복원하면 새 command 제출이 막힌다")
    func usecase_whenRestoredJobIsRunning_blockSubmit() async throws {
        // given
        let job = AIJob(jobId: "some_job") |> \.status .~ AIJob.Status.running
        let usecase = self.makeUsecaseWithRestoredJob(job)

        // when
        usecase.restoreIfNeeded()
        try await Task.sleep(for: .milliseconds(30))

        // then
        #expect(throws: (any Error).self) {
            try usecase.submit("내일 3시 미팅")
        }
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

    // 회귀: 인텐트·확장이 앱 밖에서 만든 job은 currentProcessingJobId가 nil이라 위 가드에
    // 걸려 그냥 버려졌다. 앱이 이미 포그라운드면 refreshProcessingJobIfNeeded(포그라운드
    // 복귀 트리거)도 안 타서 아무도 못 받는다 — idle 상태에서 온 미추적 푸시는 복원으로 이어받는다.
    @Test("추적 중이 아닌 job 푸시라도 idle 상태면 저장소에서 복원을 시도한다")
    func usecase_whenPushReceivedForUntrackedJob_whileIdle_restoresFromStorage() async throws {
        // given — 인텐트가 만든 job(앱 메모리엔 없음), idle 상태
        let usecase = self.makeUsecaseInIdle()

        // when
        usecase.handleJobStatusChanged("intent-made-job")

        // then — 추적 대상이 아니므로 즉시 조회가 아니라 복원 경로를 탄다
        #expect(self.stubCommand.didRefreshJobStatusWith == nil)
        #expect(self.stubCommand.didRestore == true)
    }

    // 복원이 화면 상태를 덮으면 안 되는 구간 — refreshProcessingJobIfNeeded의 가드와 동일 기준.
    @Test("추적 중이 아닌 job 푸시라도 결과를 보고 있는 중이면 복원하지 않는다")
    func usecase_whenPushReceivedForUntrackedJob_whileShowingResult_doesNotRestore() async throws {
        // given — 다른 job(job-1)의 결과를 이미 done으로 보여주고 있는 중
        let expect = expectConfirm("done 진입")
        expect.count = 2
        var done = AIJobResult.DoneResult()
        done.text = "완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        let _ = try await self.outputs(expect, for: usecase.state) {
            try? usecase.submit("회의")
        }

        // when — 추적 중이 아닌 다른 job의 푸시
        usecase.handleJobStatusChanged("intent-made-job")

        // then — done 화면을 덮지 않는다
        #expect(self.stubCommand.didRestore == false)
        #expect(self.stubCommand.didRefreshJobStatusWith == nil)
    }

    // 앱이 노는 동안 확장·인텐트가 job을 만들었을 수 있다 — 앱 메모리엔 없으니 DB에서 이어받는다
    @Test("처리 중인 job이 없으면 포그라운드 복귀 시 DB에서 복원을 시도한다")
    func usecase_whenIdleOnForeground_restoreFromStorage() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()

        // when
        usecase.refreshProcessingJobIfNeeded()

        // then — 즉시 조회가 아니라 복원 경로를 탄다
        #expect(self.stubCommand.didRefreshJobStatusWith == nil)
        #expect(self.stubCommand.didRestore == true)
    }

    // 복원이 화면 상태를 덮으면 안 되는 구간
    @Test("결과를 보고 있는 중이면 포그라운드 복귀 새로고침은 아무것도 하지 않는다")
    func usecase_whenShowingResult_foregroundRefreshDoesNothing() async throws {
        // given
        let expect = expectConfirm("done 진입")
        expect.count = 2
        var done = AIJobResult.DoneResult()
        done.text = "완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        let _ = try await self.outputs(expect, for: usecase.state) {
            try? usecase.submit("회의")
        }

        // when
        usecase.refreshProcessingJobIfNeeded()

        // then
        #expect(self.stubCommand.didRefreshJobStatusWith == nil)
        #expect(self.stubCommand.didRestore == false)
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


// MARK: - 로그아웃

extension AIAgentOrchestrationUsecaseImpleTests {

    private func makeUsecaseWithRunningJob() -> AIAgentOrchestrationUsecaseImple {
        let running = AIJob(jobId: "some_job")
            |> \.status .~ AIJob.Status.running
            |> \.command .~ "9월 10일 약속"
        let usecase = self.makeUsecaseWithRestoredJob(running)
        usecase.restoreIfNeeded()
        return usecase
    }

    // 서버 job은 살려두고 로컬 복원 근거만 지운다 — 재로그인 시 죽은 job이 되살아나는 걸 막는다
    @Test("로그아웃하면 서버 취소 없이 로컬 커맨드 기록만 지운다")
    func usecase_whenSignedOut_clearsLocalRecordWithoutServerCancel() async throws {
        // given
        let usecase = self.makeUsecaseWithRunningJob()

        // when
        await usecase.handleSignedOut()

        // then
        #expect(self.stubCommand.didClearProcessingCommandRecord == true)
        #expect(self.stubCommand.didCancelJobId == nil)
    }

    @Test("로그아웃하면 진행 중이던 상태를 idle로 되돌린다")
    func usecase_whenSignedOut_backToIdle() async throws {
        // given
        let expect = expectConfirm("로그아웃 → idle")
        let usecase = self.makeUsecaseWithRunningJob()

        // when
        let states = try await self.outputs(expect, for: usecase.state.dropFirst()) {
            Task { await usecase.handleSignedOut() }
        }

        // then
        #expect(states.map(self.stateName).last == "idle")
    }

    @Test("로그아웃하면 음성 인식도 중지한다")
    func usecase_whenSignedOut_stopsListening() async throws {
        // given
        let usecase = self.makeUsecase()
        usecase.enterVoiceInput()

        // when
        await usecase.handleSignedOut()

        // then
        #expect(self.stubSpeech.didStopListening == true)
    }
}


// MARK: - 이미지 커맨드 제출

extension AIAgentOrchestrationUsecaseImpleTests {

    // 이미지 입력 진입 시 음성 인식이 멈추고 상태가 .listening(.image)가 된다
    @Test func usecase_enterImageInput_stopsListeningAndEmitsListeningImage() async throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        usecase.enterVoiceInput()
        let expect = expectConfirm("listening(.image)")
        // when
        let state = try await self.firstOutput(expect, for: usecase.state.dropFirst()) {
            usecase.enterImageInput()
        }
        // then
        #expect(self.stubSpeech.didStopListening == true)
        if case .listening(.image) = state {} else {
            Issue.record("expected listening(.image), got \(String(describing: state))")
        }
    }

    // submitImageCommand가 .processing(command:)로 전이하고 interpret 경로로 나간다
    @Test func usecase_submitImageCommand_entersProcessingViaInterpretPath() async throws {
        // given
        let expect = expectConfirm("이미지 커맨드 전송 → processing → done")
        expect.count = 2
        var done = AIJobResult.DoneResult()
        done.text = "영수증 등록 완료"
        let usecase = self.makeUsecaseWithCommandJob(self.dummyJob(.done(done)))
        usecase.reset()
        usecase.enterImageInput()
        // when
        let states = try await self.outputs(expect, for: usecase.state.dropFirst()) {
            try? usecase.submitImageCommand(text: "영수증 텍스트", additionalInstruction: "카드값만")
        }
        // then
        #expect(states.map(self.stateName) == ["processing", "done"])
        #expect(self.stubCommand.didProcessInterpretWith?.text == "영수증 텍스트")
        #expect(self.stubCommand.didProcessInterpretWith?.instruction == "카드값만")
        #expect(self.stubCommand.didProcessInterpretWith?.source == .imageOcr)
    }

    // 원문이 10,000자를 넘으면 textTooLong을 던지고 상태는 그대로다
    @Test func usecase_submitImageCommand_whenTextTooLong_throwsAndKeepsState() throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        let tooLongText = String(repeating: "a", count: 10001)
        // when
        var caughtError: AIImageCommandSubmitFailReason?
        do {
            try usecase.submitImageCommand(text: tooLongText, additionalInstruction: nil)
        } catch let error as AIImageCommandSubmitFailReason {
            caughtError = error
        }
        // then
        #expect(caughtError == .textTooLong)
        #expect(self.stubCommand.didProcessInterpretWith == nil)
    }

    // 원문이 정확히 10,000자면 상한을 넘지 않아 처리로 진행한다
    @Test func usecase_submitImageCommand_whenTextIsExactlyAtLimit_doesNotThrow() throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        let exactText = String(repeating: "a", count: 10000)
        // when
        var caughtError: AIImageCommandSubmitFailReason?
        do {
            try usecase.submitImageCommand(text: exactText, additionalInstruction: nil)
        } catch let error as AIImageCommandSubmitFailReason {
            caughtError = error
        }
        // then
        #expect(caughtError == nil)
        #expect(self.stubCommand.didProcessInterpretWith?.text.count == 10000)
    }

    // 부가지시가 1,000자를 넘으면 instructionTooLong을 던진다
    @Test func usecase_submitImageCommand_whenInstructionTooLong_throws() throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        let tooLongInstruction = String(repeating: "b", count: 1001)
        // when
        var caughtError: AIImageCommandSubmitFailReason?
        do {
            try usecase.submitImageCommand(text: "영수증 텍스트", additionalInstruction: tooLongInstruction)
        } catch let error as AIImageCommandSubmitFailReason {
            caughtError = error
        }
        // then
        #expect(caughtError == .instructionTooLong)
        #expect(self.stubCommand.didProcessInterpretWith == nil)
    }

    // 부가지시가 정확히 1,000자면 상한을 넘지 않아 처리로 진행한다
    @Test func usecase_submitImageCommand_whenInstructionIsExactlyAtLimit_doesNotThrow() throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        let exactInstruction = String(repeating: "b", count: 1000)
        // when
        var caughtError: AIImageCommandSubmitFailReason?
        do {
            try usecase.submitImageCommand(text: "영수증 텍스트", additionalInstruction: exactInstruction)
        } catch let error as AIImageCommandSubmitFailReason {
            caughtError = error
        }
        // then
        #expect(caughtError == nil)
        #expect(self.stubCommand.didProcessInterpretWith?.instruction?.count == 1000)
    }

    // 빈 텍스트는 emptyText를 던진다
    @Test func usecase_submitImageCommand_whenEmptyText_throws() throws {
        // given
        let usecase = self.makeUsecaseInIdle()
        // when
        var caughtError: AIImageCommandSubmitFailReason?
        do {
            try usecase.submitImageCommand(text: "   ", additionalInstruction: nil)
        } catch let error as AIImageCommandSubmitFailReason {
            caughtError = error
        }
        // then
        #expect(caughtError == .emptyText)
    }

    // 이미 처리 중이면 busy를 던진다
    @Test func usecase_submitImageCommand_whileProcessing_throwsBusy() async throws {
        // given — confirm 대기 중(진짜 busy 상태)
        let usecase = self.makeUsecaseInConfirm()
        // when
        var caughtError: AIImageCommandSubmitFailReason?
        do {
            try usecase.submitImageCommand(text: "영수증 텍스트", additionalInstruction: nil)
        } catch let error as AIImageCommandSubmitFailReason {
            caughtError = error
        }
        // then
        #expect(caughtError == .busy)
    }
}
