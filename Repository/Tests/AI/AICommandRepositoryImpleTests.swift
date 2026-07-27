//
//  AICommandRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 6/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


class AICommandRepositoryImpleTests: BaseLocalTests {

    private var stubRemote: StubRemoteAPI!

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.fileName = "ai_command_test"
        self.stubRemote = .init(responses: DummyResponse().responses)
    }

    override func tearDownWithError() throws {
        self.stubRemote = nil
        try super.tearDownWithError()
    }

    private func makeRepository(
        shouldFailRemote: Bool = false
    ) -> AICommandRepositoryImple {
        self.stubRemote.shouldFailRequest = shouldFailRemote
        let localStorage = AICommandLocalStorageImple(
            sqliteService: self.sqliteService
        )
        return AICommandRepositoryImple(
            remote: self.stubRemote,
            localStorage: localStorage
        )
    }

    private func makeRepositoryWithLegacyUsageResponse() -> AICommandRepositoryImple {
        self.stubRemote = .init(responses: DummyResponse(usesLegacyUsage: true).responses)
        return self.makeRepository()
    }

    private func makeRepositoryWithUnknownPlanResponse() -> AICommandRepositoryImple {
        self.stubRemote = .init(responses: DummyResponse(usesUnknownPlan: true).responses)
        return self.makeRepository()
    }
}


// MARK: - processCommand

extension AICommandRepositoryImpleTests {

    func testRepository_processCommand_returnsJobId() async throws {
        // given
        let repository = self.makeRepository()

        // when
        let jobId = try await repository.processCommand("내일 오후 3시 회의", timeZone: "Asia/Seoul")

        // then
        XCTAssertEqual(jobId, "new_job_id")
        XCTAssertEqual(self.stubRemote.didRequestedMethod, .post)

        let params = self.stubRemote.didRequestedParams
        XCTAssertEqual(params?["command_text"] as? String, "내일 오후 3시 회의")
        XCTAssertEqual(params?["timezone"] as? String, "Asia/Seoul")
    }

    func testRepository_whenProcessCommandFail_throwError() async {
        // given
        let repository = self.makeRepository(shouldFailRemote: true)

        // when + then
        do {
            _ = try await repository.processCommand("x", timeZone: "Asia/Seoul")
            XCTFail("must throw")
        } catch {
            // expected
        }
    }
}


// MARK: - processConfirmCommand

extension AICommandRepositoryImpleTests {

    func testRepository_processConfirmCommand_returnsJobId() async throws {
        // given
        let repository = self.makeRepository()
        let args = try JSONSerialization.data(withJSONObject: ["schedule_id": "abc"])
        let action = AIConfirmCommandAction()
            |> \.tool .~ "delete_schedule"
            |> \.confirmToken .~ "tok"
            |> \.parentJobId .~ "parent-xyz"
            |> \.args .~ args

        // when
        let jobId = try await repository.processConfirmCommand(action, timeZone: "Asia/Seoul")

        // then
        XCTAssertEqual(jobId, "confirm_job_id")
        XCTAssertEqual(self.stubRemote.didRequestedMethod, .post)

        let params = self.stubRemote.didRequestedParams
        XCTAssertEqual(params?["tool"] as? String, "delete_schedule")
        XCTAssertEqual(params?["confirm_token"] as? String, "tok")
        XCTAssertEqual(params?["parent_job_id"] as? String, "parent-xyz")
        XCTAssertEqual(params?["timezone"] as? String, "Asia/Seoul")
        let argsParam = params?["args"] as? [String: Any]
        XCTAssertEqual(argsParam?["schedule_id"] as? String, "abc")
    }

    func testRepository_rejectConfirmCommand_postsParentJobId() async throws {
        // given
        let repository = self.makeRepository()
        let action = AIConfirmCommandAction()
            |> \.parentJobId .~ "parent-123"

        // when
        try await repository.rejectConfirmCommand(action)

        // then
        XCTAssertEqual(self.stubRemote.didRequestedMethod, .post)
        XCTAssertEqual(self.stubRemote.didRequestedPath?.contains("command/reject"), true)
        XCTAssertEqual(self.stubRemote.didRequestedParams?["job_id"] as? String, "parent-123")
    }

    func testRepository_cancelCommand_postsJobIdToCancelEndpoint() async throws {
        // given
        let repository = self.makeRepository()

        // when
        try await repository.cancelCommand("job-123")

        // then
        XCTAssertEqual(self.stubRemote.didRequestedMethod, .post)
        XCTAssertEqual(self.stubRemote.didRequestedPath?.contains("command/cancel"), true)
        XCTAssertEqual(self.stubRemote.didRequestedParams?["job_id"] as? String, "job-123")
    }
}


// MARK: - loadJob

extension AICommandRepositoryImpleTests {

    func testRepository_loadJob_done() async throws {
        // given
        let repository = self.makeRepository()

        // when
        let job = try await repository.loadJob("done_job")

        // then
        XCTAssertEqual(job.jobId, "done_job")
        XCTAssertEqual(job.status, .done)
        XCTAssertEqual(job.mode, .command)
        XCTAssertEqual(job.command, "내일 오후 3시")
        guard case .done(let result) = job.result else {
            XCTFail("expect done result"); return
        }
        XCTAssertEqual(result.text, "일정 등록했어요")
        XCTAssertEqual(result.mutations.map { $0.dataType }, [.schedule])
        XCTAssertEqual(result.mutations.map { $0.operation }, [.created])
        XCTAssertNotNil(job.createAt)
        XCTAssertNotNil(job.updatedAt)
    }

    func testRepository_loadJob_confirm_keepsArgsAsRawData() async throws {
        // given
        let repository = self.makeRepository()

        // when
        let job = try await repository.loadJob("confirm_job")

        // then
        XCTAssertEqual(job.status, .confirm)
        guard case .confirm(let result) = job.result else {
            XCTFail("expect confirm result"); return
        }
        XCTAssertEqual(result.text, "정말 삭제할까요")
        XCTAssertEqual(result.action?.tool, "delete_schedule")
        XCTAssertEqual(result.action?.confirmToken, "tok-confirm")

        let argsObject = try result.action?.args
            .flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        XCTAssertEqual(argsObject?["schedule_id"] as? String, "abc")
    }

    func testRepository_loadJob_failed() async throws {
        // given
        let repository = self.makeRepository()

        // when
        let job = try await repository.loadJob("failed_job")

        // then
        XCTAssertEqual(job.status, .failed)
        guard case .failed(let result) = job.result else {
            XCTFail("expect failed result"); return
        }
        XCTAssertEqual(result.reason, "한도 소진")
        XCTAssertEqual(result.errorCode, .dailyLimitExceeded)
    }

    func testRepository_loadJob_running() async throws {
        // given
        let repository = self.makeRepository()

        // when
        let job = try await repository.loadJob("running_job")

        // then
        XCTAssertEqual(job.status, .running)
        XCTAssertFalse(job.isFinish)
        XCTAssertNil(job.result)
    }

    func testRepository_loadJob_canceled_parsesMutations() async throws {
        // given
        let repository = self.makeRepository()

        // when
        let job = try await repository.loadJob("canceled_job")

        // then — CANCELED result의 mutation이 파싱된다
        XCTAssertEqual(job.status, .canceled)
        guard case .canceled(let result) = job.result else {
            XCTFail("expect canceled result"); return
        }
        XCTAssertEqual(result.mutations.map { $0.dataType }, [.todo])
        XCTAssertEqual(result.mutations.map { $0.operation }, [.created])
    }
}


// MARK: - loadUsage

extension AICommandRepositoryImpleTests {

    func testRepository_loadUsage() async throws {
        // given
        let repository = self.makeRepository()

        // when
        let usage = try await repository.loadUsage()

        // then
        XCTAssertEqual(usage.date, "2026-06-01")
        XCTAssertEqual(usage.inputTokens, 1250)
        XCTAssertEqual(usage.outputTokens, 320)
        XCTAssertEqual(usage.dailyLimit, 5000)
        XCTAssertNotNil(usage.updatedAt)
        XCTAssertEqual(usage.creditsUsed, 1400)
        XCTAssertEqual(usage.resetsAt?.timeIntervalSince1970, 1780358400)
        XCTAssertEqual(usage.plan, .standard)
        XCTAssertEqual(usage.topupRemaining, 12300)
        XCTAssertEqual(usage.scheduledPlanChange?.planId, .free)
        XCTAssertEqual(
            usage.scheduledPlanChange?.effectiveAt.timeIntervalSince1970, 1787702400
        )
    }

    func testRepository_whenUsageResponseHasNoCreditFields_creditFieldsAreNil() async throws {
        // given
        let repository = self.makeRepositoryWithLegacyUsageResponse()

        // when
        let usage = try await repository.loadUsage()

        // then
        XCTAssertNil(usage.creditsUsed)
        XCTAssertNil(usage.resetsAt)
        XCTAssertEqual(usage.dailyLimit, 5000)
        XCTAssertNil(usage.plan)
        XCTAssertNil(usage.scheduledPlanChange)
        XCTAssertNil(usage.topupRemaining)
    }

    // 모르는 플랜 id는 파싱 실패로 두고 나머지 필드는 살린다 — 칩만 안 뜨고 게이지는 정상
    // (같은 픽스처가 scheduled_change: null 도 함께 담는다)
    func testRepository_whenPlanIdIsUnknown_planIsNilButOtherFieldsRemain() async throws {
        // given
        let repository = self.makeRepositoryWithUnknownPlanResponse()

        // when
        let usage = try await repository.loadUsage()

        // then
        XCTAssertNil(usage.plan)
        XCTAssertEqual(usage.topupRemaining, 500)
        XCTAssertEqual(usage.creditsUsed, 1400)
        XCTAssertNil(usage.scheduledPlanChange)
    }
}


// MARK: - ProcessingAICommand persistence

extension AICommandRepositoryImpleTests {

    func testRepository_loadProcessingCommand_whenNotExists_isNil() async throws {
        // given
        let repository = self.makeRepository()

        // when
        let loaded = try await repository.loadProcessingAICommand()

        // then
        XCTAssertNil(loaded)
    }

    func testRepository_updateProcessingCommand_andLoad() async throws {
        // given
        let repository = self.makeRepository()
        let cmd = ProcessingAICommand(jobId: "saved", isConfirmJob: false)

        // when
        try await repository.updateProcessingAICommand(cmd)
        let loaded = try await repository.loadProcessingAICommand()

        // then
        XCTAssertEqual(loaded?.jobId, "saved")
        XCTAssertEqual(loaded?.isConfirmJob, false)
    }

    func testRepository_updateProcessingCommand_isConfirmJobTrue_roundTrip() async throws {
        // given
        let repository = self.makeRepository()
        let cmd = ProcessingAICommand(jobId: "confirm_cmd", isConfirmJob: true)

        // when
        try await repository.updateProcessingAICommand(cmd)
        let loaded = try await repository.loadProcessingAICommand()

        // then
        XCTAssertEqual(loaded?.jobId, "confirm_cmd")
        XCTAssertEqual(loaded?.isConfirmJob, true)
    }

    func testRepository_updateProcessingCommand_replacesPrevious() async throws {
        // given
        let repository = self.makeRepository()

        // when
        try await repository.updateProcessingAICommand(.init(jobId: "first", isConfirmJob: false))
        try await repository.updateProcessingAICommand(.init(jobId: "second", isConfirmJob: true))
        let loaded = try await repository.loadProcessingAICommand()

        // then
        XCTAssertEqual(loaded?.jobId, "second")
        XCTAssertEqual(loaded?.isConfirmJob, true)
    }

    func testRepository_clearProcessingCommand() async throws {
        // given
        let repository = self.makeRepository()
        try await repository.updateProcessingAICommand(.init(jobId: "to_clear", isConfirmJob: false))

        // when
        try await repository.clearProcessingAICommand()
        let loaded = try await repository.loadProcessingAICommand()

        // then
        XCTAssertNil(loaded)
    }
}


// MARK: - DummyResponse

import Prelude
import Optics

private struct DummyResponse {

    var usesLegacyUsage: Bool = false
    var usesUnknownPlan: Bool = false

    var responses: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .post,
                endpoint: AIAPIEndpoints.command,
                resultJsonString: .success(self.commandJobIdJson)
            ),
            .init(
                method: .post,
                endpoint: AIAPIEndpoints.confirmCommand,
                resultJsonString: .success(self.confirmJobIdJson)
            ),
            .init(
                method: .post,
                endpoint: AIAPIEndpoints.rejectCommand,
                resultJsonString: .success(#"{ "ok": true }"#)
            ),
            .init(
                method: .post,
                endpoint: AIAPIEndpoints.cancelCommand,
                resultJsonString: .success("{}")
            ),
            .init(
                method: .get,
                endpoint: AIAPIEndpoints.job(id: "done_job"),
                resultJsonString: .success(self.doneJobJson)
            ),
            .init(
                method: .get,
                endpoint: AIAPIEndpoints.job(id: "confirm_job"),
                resultJsonString: .success(self.confirmJobJson)
            ),
            .init(
                method: .get,
                endpoint: AIAPIEndpoints.job(id: "failed_job"),
                resultJsonString: .success(self.failedJobJson)
            ),
            .init(
                method: .get,
                endpoint: AIAPIEndpoints.job(id: "running_job"),
                resultJsonString: .success(self.runningJobJson)
            ),
            .init(
                method: .get,
                endpoint: AIAPIEndpoints.job(id: "canceled_job"),
                resultJsonString: .success(self.canceledJobJson)
            ),
            .init(
                method: .get,
                endpoint: AIAPIEndpoints.usage,
                resultJsonString: .success(self.usageResponseJson)
            )
        ]
    }

    private var usageResponseJson: String {
        if self.usesLegacyUsage { return self.legacyUsageJson }
        if self.usesUnknownPlan { return self.unknownPlanUsageJson }
        return self.usageJson
    }

    private var commandJobIdJson: String {
        return #"{ "job_id": "new_job_id" }"#
    }

    private var confirmJobIdJson: String {
        return #"{ "job_id": "confirm_job_id" }"#
    }

    private var doneJobJson: String {
        return """
        {
            "job_id": "done_job",
            "command_text": "내일 오후 3시",
            "status": "DONE",
            "mode": "command",
            "created_at": "2026-06-01T10:00:00.000Z",
            "updated_at": "2026-06-01T10:00:05.000Z",
            "result": {
                "type": "DONE",
                "text": "일정 등록했어요",
                "mutations": [
                    { "dataType": "schedule", "op": "created" }
                ]
            }
        }
        """
    }

    private var confirmJobJson: String {
        return """
        {
            "job_id": "confirm_job",
            "status": "CONFIRM",
            "mode": "command",
            "result": {
                "type": "CONFIRM",
                "text": "정말 삭제할까요",
                "action": {
                    "tool": "delete_schedule",
                    "args": { "schedule_id": "abc" },
                    "confirmToken": "tok-confirm"
                },
                "mutations": []
            }
        }
        """
    }

    private var failedJobJson: String {
        return """
        {
            "job_id": "failed_job",
            "status": "FAILED",
            "mode": "command",
            "result": {
                "type": "FAILED",
                "reason": "한도 소진",
                "errorCode": "DailyLimitExceeded",
                "mutations": []
            }
        }
        """
    }

    private var runningJobJson: String {
        return """
        {
            "job_id": "running_job",
            "status": "RUNNING",
            "mode": "command"
        }
        """
    }

    private var canceledJobJson: String {
        return """
        {
            "job_id": "canceled_job",
            "status": "CANCELED",
            "mode": "command",
            "result": {
                "type": "CANCELED",
                "text": "중지했어요",
                "mutations": [
                    { "dataType": "todo", "op": "created" }
                ]
            }
        }
        """
    }

    private var usageJson: String {
        return """
        {
            "date": "2026-06-01",
            "input_tokens": 1250,
            "output_tokens": 320,
            "daily_limit": 5000,
            "credits_used": 1400,
            "resets_at": "2026-06-02T00:00:00.000Z",
            "updated_at": "2026-06-01T10:00:00.000Z",
            "plan": {
                "id": "standard",
                "scheduled_change": {
                    "plan_id": "free",
                    "effective_at": "2026-08-26T00:00:00.000Z"
                }
            },
            "topup_remaining": 12300
        }
        """
    }

    // 서버 미배포 구간 응답 — credits_used·resets_at 없음
    private var legacyUsageJson: String {
        return """
        {
            "date": "2026-06-01",
            "input_tokens": 1250,
            "output_tokens": 320,
            "daily_limit": 5000,
            "updated_at": "2026-06-01T10:00:00.000Z"
        }
        """
    }

    // 서버가 앱이 모르는 플랜 id를 내려주는 경우 (플랜 추가 배포 시점 차)
    private var unknownPlanUsageJson: String {
        return """
        {
            "date": "2026-06-01",
            "input_tokens": 1250,
            "output_tokens": 320,
            "daily_limit": 5000,
            "credits_used": 1400,
            "plan": { "id": "enterprise", "scheduled_change": null },
            "topup_remaining": 500
        }
        """
    }
}
