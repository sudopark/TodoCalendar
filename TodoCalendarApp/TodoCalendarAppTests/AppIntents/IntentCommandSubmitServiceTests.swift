//
//  IntentCommandSubmitServiceTests.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Prelude
import Optics
import Domain
import Repository
import Extensions
import TestDoubles

@testable import TodoCalendarApp


final class IntentCommandSubmitServiceTests {

    private func makeService(
        hasAuth: Bool = true,
        stubRepository: StubAICommandRepository = .init()
    ) -> (IntentCommandSubmitService, StubAICommandRepository) {
        let settingRepository = StubCalendarSettingRepository()
        settingRepository.saveTimeZone(TimeZone(identifier: "Asia/Seoul")!)
        let service = IntentCommandSubmitService(
            repository: stubRepository,
            authStore: StubAuthStore(
                auth: hasAuth ? Auth(uid: "uid", accessToken: "token") : nil
            ),
            settingRepository: settingRepository
        )
        return (service, stubRepository)
    }

    private func makeRepository(
        processFailWith error: (any Error)? = nil,
        pending: ProcessingAICommand? = nil,
        shouldFailLoadPending: Bool = false,
        shouldFailUpdatePending: Bool = false
    ) -> StubAICommandRepository {
        let repository = StubAICommandRepository()
        repository.stubProcessError = error
        repository.stubPendingCommand = pending
        repository.shouldFailLoadPending = shouldFailLoadPending
        repository.shouldFailUpdatePending = shouldFailUpdatePending
        return repository
    }

    private func failReason(
        of submit: () async throws -> Void
    ) async -> AICommandSubmitFailReason? {
        do {
            try await submit()
            return nil
        } catch {
            return error as? AICommandSubmitFailReason
        }
    }
}

// MARK: - 로그인 상태

extension IntentCommandSubmitServiceTests {

    @Test("로그인 상태면 커맨드를 전송하고 처리중으로 기록한다")
    func submit_whenSignedIn_submits() async {
        // given
        let (service, repository) = self.makeService()

        // when
        let reason = await self.failReason { try await service.submit("내일 3시 회의") }

        // then
        #expect(reason == nil)
        #expect(repository.didProcessCommandText == "내일 3시 회의")
        #expect(repository.didProcessTimeZone == "Asia/Seoul")
        #expect(repository.didUpdatePendingJobId == "some_job")
    }

    @Test("미로그인이면 전송하지 않고 notSignedIn으로 실패한다")
    func submit_whenNotSignedIn_notSubmits() async {
        // given
        let (service, repository) = self.makeService(hasAuth: false)

        // when
        let reason = await self.failReason { try await service.submit("내일 3시 회의") }

        // then
        #expect(reason == .notSignedIn)
        #expect(repository.didProcessCommandText == nil)
    }
}

// MARK: - 미확인 요청 가드

extension IntentCommandSubmitServiceTests {

    // ProcessingAICommand는 단일 행이다. 통과시켜 제출하면 앱이 추적 중인 job의 기록이
    // 덮여 앞선 결과가 유실된다.
    @Test("앞선 요청이 남아있으면 서버로 보내지 않는다")
    func submit_whenPreviousRequestPending_notSubmits() async {
        // given
        let repository = self.makeRepository(
            pending: ProcessingAICommand(jobId: "previous_job", isConfirmJob: false)
        )
        let (service, _) = self.makeService(stubRepository: repository)

        // when
        let reason = await self.failReason { try await service.submit("내일 3시 회의") }

        // then
        #expect(reason == .previousRequestPending)
        #expect(repository.didProcessCommandText == nil)
    }

    // fail-closed — 유무를 확인 못 했는데 통과시키면 위와 같은 유실이 난다.
    @Test("앞선 요청 유무 조회가 실패하면 서버로 보내지 않는다")
    func submit_whenLoadPendingFails_notSubmits() async {
        // given
        let repository = self.makeRepository(shouldFailLoadPending: true)
        let (service, _) = self.makeService(stubRepository: repository)

        // when
        let reason = await self.failReason { try await service.submit("내일 3시 회의") }

        // then
        #expect(reason == .previousRequestPending)
        #expect(repository.didProcessCommandText == nil)
    }
}

// MARK: - 전송 실패 분류

extension IntentCommandSubmitServiceTests {

    @Test("한도 초과 서버 에러는 limitExceeded로 분류한다")
    func submit_whenDailyLimitExceeded_returnsLimitExceeded() async {
        // given
        let error = ServerErrorModel()
            |> \.code .~ ServerErrorModel.ErrorCode.dailyLimitExceeded
        let (service, _) = self.makeService(
            stubRepository: self.makeRepository(processFailWith: error)
        )

        // when
        let reason = await self.failReason { try await service.submit("내일 3시 회의") }

        // then
        #expect(reason == .limitExceeded)
    }

    @Test("그 외 에러는 unknown으로 분류한다")
    func submit_whenOtherError_returnsUnknown() async {
        // given
        let (service, _) = self.makeService(
            stubRepository: self.makeRepository(processFailWith: RuntimeError("network down"))
        )

        // when
        let reason = await self.failReason { try await service.submit("내일 3시 회의") }

        // then
        #expect(reason == .unknown)
    }

    @Test(
        "로컬 Auth는 남아있지만 서버 세션이 죽은 에러는 notSignedIn으로 분류한다",
        arguments: [ServerErrorModel.ErrorCode.unauthorized, .invalidAccessKey]
    )
    func submit_whenServerSessionDead_returnsNotSignedIn(_ code: ServerErrorModel.ErrorCode) async {
        // given
        let error = ServerErrorModel() |> \.code .~ code
        let (service, _) = self.makeService(
            stubRepository: self.makeRepository(processFailWith: error)
        )

        // when
        let reason = await self.failReason { try await service.submit("내일 3시 회의") }

        // then
        #expect(reason == .notSignedIn)
    }

    // job은 서버에 만들어졌지만 로컬 기록에 실패한 경우 — unknown으로 떨어지면 유저가
    // "다시 시도"를 믿고 재전송해 중복 job이 생긴다. 별도 케이스로 분류돼야 한다.
    @Test("job은 만들어졌지만 기록에 실패하면 processingCommandRecordFailed로 분류한다")
    func submit_whenRecordFails_returnsRecordFailed() async {
        // given
        let (service, _) = self.makeService(
            stubRepository: self.makeRepository(shouldFailUpdatePending: true)
        )

        // when
        let reason = await self.failReason { try await service.submit("내일 3시 회의") }

        // then
        #expect(reason == .processingCommandRecordFailed)
    }
}


private final class StubAuthStore: AuthStore, @unchecked Sendable {

    private var auth: Auth?
    init(auth: Auth?) {
        self.auth = auth
    }

    func loadCurrentAuth() -> Auth? {
        return self.auth
    }

    func saveAuth(_ auth: Auth) {
        self.auth = auth
    }

    func removeAuth() {
        self.auth = nil
    }
}

private final class StubAICommandRepository: AICommandRepository, @unchecked Sendable {

    var stubProcessError: (any Error)?
    var stubPendingCommand: ProcessingAICommand?
    var shouldFailLoadPending: Bool = false
    var shouldFailUpdatePending: Bool = false

    var didProcessCommandText: String?
    var didProcessTimeZone: String?
    var didUpdatePendingJobId: String?

    func processCommand(_ commandText: String, timeZone: String) async throws -> String {
        if let stubProcessError { throw stubProcessError }
        self.didProcessCommandText = commandText
        self.didProcessTimeZone = timeZone
        return "some_job"
    }

    func processInterpretCommand(
        text: String,
        additionalInstruction: String?,
        timeZone: String
    ) async throws -> String {
        throw RuntimeError("intent path does not use interpret")
    }

    func loadProcessingAICommand() async throws -> ProcessingAICommand? {
        guard !self.shouldFailLoadPending
        else { throw RuntimeError("failed to load processing command") }
        return self.stubPendingCommand
    }

    func updateProcessingAICommand(_ cmd: ProcessingAICommand) async throws {
        guard !self.shouldFailUpdatePending
        else { throw RuntimeError("failed to update processing command") }
        self.didUpdatePendingJobId = cmd.jobId
    }

    func clearProcessingAICommand() async throws { }

    func processConfirmCommand(_ action: AIConfirmCommandAction, timeZone: String) async throws -> String {
        throw RuntimeError("not imple")
    }

    func rejectConfirmCommand(_ action: AIConfirmCommandAction) async throws { }

    func cancelCommand(_ jobId: String) async throws { }

    func loadJob(_ jobId: String) async throws -> AIJob {
        throw RuntimeError("not imple")
    }

    func loadUsage() async throws -> AIAgentUsageLoadResult {
        throw RuntimeError("not imple")
    }
}
