//
//  ShareCommandSubmitServiceTests.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Domain
import Repository
import Extensions

@testable import TodoCalendarAppShare


final class ShareCommandSubmitServiceTests {

    fileprivate func makeService(
        hasAuth: Bool = true,
        repository: StubAICommandRepository = .init()
    ) -> (ShareCommandSubmitService, StubAICommandRepository) {
        let service = ShareCommandSubmitService(
            repository: repository,
            authStore: StubAuthStore(
                auth: hasAuth ? Auth(uid: "uid", accessToken: "token") : nil
            )
        )
        return (service, repository)
    }
}


// MARK: - 제출 전제 판정

extension ShareCommandSubmitServiceTests {

    @Test("미로그인이면 로그인 필요로 판정한다")
    func checkPrecondition_whenNotSignedIn() async {
        // given
        let (service, _) = self.makeService(hasAuth: false)

        // when
        let precondition = await service.checkPrecondition()

        // then
        #expect(precondition == .needSignIn)
    }

    @Test("앞선 요청이 남아있으면 대기중으로 판정한다")
    func checkPrecondition_whenPendingExists() async {
        // given
        let repository = StubAICommandRepository()
        repository.stubPendingCommand = .init(jobId: "job", isConfirmJob: false)
        let (service, _) = self.makeService(repository: repository)

        // when
        let precondition = await service.checkPrecondition()

        // then
        #expect(precondition == .previousRequestPending)
    }

    @Test("앞선 요청 유무 확인에 실패하면 통과시키지 않는다 (fail-closed)")
    func checkPrecondition_whenLoadFails_blocks() async {
        // given
        let repository = StubAICommandRepository()
        repository.shouldFailLoadPending = true
        let (service, _) = self.makeService(repository: repository)

        // when
        let precondition = await service.checkPrecondition()

        // then
        #expect(precondition == .previousRequestPending)
    }

    @Test("로그인 + 앞선 요청 없음이면 준비 완료로 판정한다")
    func checkPrecondition_whenReady() async {
        // given
        let (service, _) = self.makeService()

        // when
        let precondition = await service.checkPrecondition()

        // then
        #expect(precondition == .ready)
    }
}


// MARK: - doubles

// AICommandRepository 구현체는 앱 타겟 테스트(IntentCommandSubmitServiceTests)에도
// 로컬로 하나 있다. 타겟이 달라 공유가 안 되므로 여기 따로 둔다 —
// 세 번째 소비자가 생기면 TestDoubles로 승격할 것.
final class StubAICommandRepository: AICommandRepository, @unchecked Sendable {

    var stubPendingCommand: ProcessingAICommand?
    var shouldFailLoadPending: Bool = false
    var shouldFailUpdatePending: Bool = false
    var stubProcessError: (any Error)?

    var didProcessInterpretText: String?
    var didProcessInterpretAdditionalInstruction: String?
    var didUpdatePendingJobId: String?

    func processInterpretCommand(
        text: String,
        additionalInstruction: String?,
        timeZone: String
    ) async throws -> String {
        if let stubProcessError { throw stubProcessError }
        self.didProcessInterpretText = text
        self.didProcessInterpretAdditionalInstruction = additionalInstruction
        return "some_job"
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
    func processCommand(_ commandText: String, timeZone: String) async throws -> String {
        throw RuntimeError("share path does not use command")
    }
    func processConfirmCommand(
        _ action: AIConfirmCommandAction, timeZone: String
    ) async throws -> String {
        throw RuntimeError("not used")
    }
    func rejectConfirmCommand(_ action: AIConfirmCommandAction) async throws { }
    func cancelCommand(_ jobId: String) async throws { }
    func loadJob(_ jobId: String) async throws -> AIJob { throw RuntimeError("not used") }
    func loadUsage() async throws -> AIAgentUsageLoadResult { throw RuntimeError("not used") }
}


final class StubAuthStore: AuthStore, @unchecked Sendable {

    private let auth: Auth?
    init(auth: Auth?) { self.auth = auth }

    func loadCurrentAuth() -> Auth? { return self.auth }
    func saveAuth(_ auth: Auth) { }
    func removeAuth() { }
}
