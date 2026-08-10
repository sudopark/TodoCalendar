//
//  ShareCommandSubmitServiceTests.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Prelude
import Optics
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
        let repository = makeStubAICommandRepository(
            pending: .init(jobId: "job", isConfirmJob: false)
        )
        let (service, _) = self.makeService(repository: repository)

        // when
        let precondition = await service.checkPrecondition()

        // then
        #expect(precondition == .previousRequestPending)
    }

    @Test("앞선 요청 유무 확인에 실패하면 통과시키지 않는다 (fail-closed)")
    func checkPrecondition_whenLoadFails_blocks() async {
        // given
        let repository = makeStubAICommandRepository(shouldFailLoadPending: true)
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


// MARK: - 제출

extension ShareCommandSubmitServiceTests {

    @Test("원문과 부가지시를 조립 없이 그대로 넘긴다")
    func submit_passesRawTextAndInstruction() async throws {
        // given
        let (service, repository) = self.makeService()

        // when
        try await service.submit(
            sharedText: "9월 10일 약속",
            additionalInstruction: "오후 3시로 잡아줘"
        )

        // then
        #expect(repository.didProcessInterpretText == "9월 10일 약속")
        #expect(repository.didProcessInterpretAdditionalInstruction == "오후 3시로 잡아줘")
        #expect(repository.didUpdatePendingJobId == "some_job")
    }

    @Test("입력 출처는 텍스트로 보낸다")
    func submit_sendsInputSourceAsText() async throws {
        // given
        let (service, repository) = self.makeService()

        // when
        try await service.submit(
            sharedText: "9월 10일 약속",
            additionalInstruction: "오후 3시로 잡아줘"
        )

        // then
        #expect(repository.didProcessInterpretWithInputSource == .text)
    }

    @Test("앞뒤 공백은 제거하고 넘긴다")
    func submit_trimsInputs() async throws {
        // given
        let (service, repository) = self.makeService()

        // when
        try await service.submit(
            sharedText: "  9월 10일 약속\n\n",
            additionalInstruction: "\t오후 3시로 잡아줘  "
        )

        // then
        #expect(repository.didProcessInterpretText == "9월 10일 약속")
        #expect(repository.didProcessInterpretAdditionalInstruction == "오후 3시로 잡아줘")
    }

    @Test("부가지시가 공백뿐이면 없는 것으로 넘긴다")
    func submit_whenInstructionIsBlank_passesNil() async throws {
        // given
        let (service, repository) = self.makeService()

        // when
        try await service.submit(sharedText: "9월 10일 약속", additionalInstruction: "   ")

        // then
        #expect(repository.didProcessInterpretAdditionalInstruction == nil)
    }

    @Test("원문이 공백뿐이면 보내지 않는다")
    func submit_whenTextIsBlank_throws() async {
        // given
        let (service, repository) = self.makeService()

        // when
        let failure = await self.captureFailure {
            try await service.submit(sharedText: " \n ", additionalInstruction: "")
        }

        // then
        #expect(failure as? ShareSubmitFailure == .emptyCommand)
        #expect(repository.didProcessInterpretText == nil)
    }

    @Test("원문이 상한을 넘으면 보내지 않는다")
    func submit_whenTextExceedsLimit_throws() async {
        // given
        let (service, repository) = self.makeService()
        let tooLong = String(repeating: "가", count: 10001)

        // when
        let failure = await self.captureFailure {
            try await service.submit(sharedText: tooLong, additionalInstruction: "")
        }

        // then
        #expect(failure as? ShareSubmitFailure == .sharedTextTooLong)
        #expect(repository.didProcessInterpretText == nil)
    }

    @Test("상한과 같은 길이는 통과한다")
    func submit_whenTextIsExactlyAtLimit_passes() async throws {
        // given
        let (service, repository) = self.makeService()
        let exact = String(repeating: "가", count: 10000)

        // when
        try await service.submit(sharedText: exact, additionalInstruction: "")

        // then
        #expect(repository.didProcessInterpretText?.count == 10000)
    }

    @Test("부가지시가 상한을 넘으면 보내지 않는다")
    func submit_whenInstructionExceedsLimit_throws() async {
        // given
        let (service, repository) = self.makeService()
        let tooLong = String(repeating: "가", count: 1001)

        // when
        let failure = await self.captureFailure {
            try await service.submit(sharedText: "9월 10일 약속", additionalInstruction: tooLong)
        }

        // then
        #expect(failure as? ShareSubmitFailure == .additionalInstructionTooLong)
        #expect(repository.didProcessInterpretText == nil)
    }

    @Test("부가지시가 상한과 같은 길이면 통과한다")
    func submit_whenInstructionIsExactlyAtLimit_passes() async throws {
        // given
        let (service, repository) = self.makeService()
        let exact = String(repeating: "가", count: 1000)

        // when
        try await service.submit(sharedText: "9월 10일 약속", additionalInstruction: exact)

        // then
        #expect(repository.didProcessInterpretAdditionalInstruction?.count == 1000)
    }

    @Test("제출 자체가 실패하면 에러를 그대로 전파한다")
    func submit_whenProcessFails_throwsUnderlyingError() async {
        // given
        let repository = makeStubAICommandRepository(
            processFailWith: RuntimeError("network is down")
        )
        let (service, _) = self.makeService(repository: repository)

        // when
        let failure = await self.captureFailure {
            try await service.submit(sharedText: "9월 10일 약속", additionalInstruction: "")
        }

        // then
        #expect((failure as? RuntimeError)?.message == "network is down")
        #expect(repository.didUpdatePendingJobId == nil)
    }

    @Test("job은 만들어졌는데 기록에 실패하면 추적 불가로 알린다")
    func submit_whenRecordFails_throwsNotTrackable() async {
        // given
        let repository = makeStubAICommandRepository(shouldFailUpdatePending: true)
        let (service, _) = self.makeService(repository: repository)

        // when
        let failure = await self.captureFailure {
            try await service.submit(sharedText: "9월 10일 약속", additionalInstruction: "")
        }

        // then
        #expect(failure as? ShareSubmitFailure == .createdButNotTrackable)
    }

    private func captureFailure(
        _ action: () async throws -> Void
    ) async -> (any Error)? {
        do {
            try await action()
            return nil
        } catch {
            return error
        }
    }
}


// MARK: - 입력 출처 전달

extension ShareCommandSubmitServiceTests {

    @Test("출처를 안 주면 텍스트로 보낸다")
    func submit_whenNoInputSourceGiven_sendsText() async throws {
        // given
        let (service, repository) = self.makeService()

        // when
        try await service.submit(sharedText: "내일 회의", additionalInstruction: "")

        // then
        #expect(repository.didProcessInterpretWithInputSource == .text)
    }

    @Test("이미지 OCR 출처를 그대로 보낸다")
    func submit_whenImageOcrGiven_sendsImageOcr() async throws {
        // given
        let (service, repository) = self.makeService()

        // when
        try await service.submit(
            sharedText: "9월 10일 치과",
            additionalInstruction: "",
            inputSource: .imageOcr
        )

        // then
        #expect(repository.didProcessInterpretWithInputSource == .imageOcr)
    }
}


// MARK: - 크레딧 소진 전제

extension ShareCommandSubmitServiceTests {

    private func exhaustedUsage() -> AIAgentUsageLoadResult {
        return AIAgentUsageLoadResult(
            usage: AIAgentUsage(input: 0, output: 0, limit: 3000)
                |> \.creditsUsed .~ 3000,
            userPlan: BillingUserPlan() |> \.topupRemaining .~ 0
        )
    }

    private func remainingUsage() -> AIAgentUsageLoadResult {
        return AIAgentUsageLoadResult(
            usage: AIAgentUsage(input: 0, output: 0, limit: 3000)
                |> \.creditsUsed .~ 10,
            userPlan: BillingUserPlan() |> \.topupRemaining .~ 0
        )
    }

    @Test("크레딧이 소진됐으면 전제 판정이 소진으로 나온다")
    func service_whenCreditExhausted_preconditionIsCreditExhausted() async {
        // given
        let repository = makeStubAICommandRepository(usageLoadResult: self.exhaustedUsage())
        let (service, _) = self.makeService(repository: repository)

        // when
        let precondition = await service.checkPrecondition()

        // then
        #expect(precondition == .creditExhausted)
    }

    @Test("크레딧이 남았으면 전제 판정이 통과다")
    func service_whenCreditRemains_preconditionIsReady() async {
        // given
        let repository = makeStubAICommandRepository(usageLoadResult: self.remainingUsage())
        let (service, _) = self.makeService(repository: repository)

        // when
        let precondition = await service.checkPrecondition()

        // then
        #expect(precondition == .ready)
    }

    @Test("usage 조회에 실패하면 막지 않는다")
    func service_whenUsageLoadFails_preconditionIsReady() async {
        // given
        let repository = makeStubAICommandRepository(shouldFailLoadUsage: true)
        let (service, _) = self.makeService(repository: repository)

        // when
        let precondition = await service.checkPrecondition()

        // then
        #expect(precondition == .ready)
    }

    @Test("앞선 요청이 있으면 usage 조회 전에 그 판정이 우선한다")
    func service_whenPreviousRequestPending_doesNotCheckCredit() async {
        // given
        let repository = makeStubAICommandRepository(
            pending: .init(jobId: "job-1", isConfirmJob: false),
            usageLoadResult: self.exhaustedUsage()
        )
        let (service, _) = self.makeService(repository: repository)

        // when
        let precondition = await service.checkPrecondition()

        // then
        #expect(precondition == .previousRequestPending)
        #expect(repository.didLoadUsage == false)
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
    var stubUsageLoadResult: AIAgentUsageLoadResult?
    var shouldFailLoadUsage: Bool = false

    var didProcessInterpretText: String?
    var didProcessInterpretAdditionalInstruction: String?
    var didProcessInterpretWithInputSource: AICommandInputSource?
    var didUpdatePendingJobId: String?
    var didLoadUsage: Bool = false

    func processInterpretCommand(
        text: String,
        additionalInstruction: String?,
        inputSource: AICommandInputSource,
        timeZone: String
    ) async throws -> String {
        if let stubProcessError { throw stubProcessError }
        self.didProcessInterpretWithInputSource = inputSource
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
    func loadUsage() async throws -> AIAgentUsageLoadResult {
        self.didLoadUsage = true
        guard !self.shouldFailLoadUsage
        else { throw RuntimeError("failed to load usage") }
        return self.stubUsageLoadResult ?? AIAgentUsageLoadResult(
            usage: AIAgentUsage(input: 0, output: 0, limit: 3000),
            userPlan: BillingUserPlan() |> \.topupRemaining .~ 0
        )
    }
}

// ShareCommandSubmitServiceTests·ShareCommandViewModelTests가 공유하는 팩토리 —
// 테스트 본문에서 stub을 직접 mutate하지 않도록 여기 한 곳에 모은다 (testability.md §2).
func makeStubAICommandRepository(
    pending: ProcessingAICommand? = nil,
    processFailWith error: (any Error)? = nil,
    shouldFailLoadPending: Bool = false,
    shouldFailUpdatePending: Bool = false,
    usageLoadResult: AIAgentUsageLoadResult? = nil,
    shouldFailLoadUsage: Bool = false
) -> StubAICommandRepository {
    let repository = StubAICommandRepository()
    repository.stubPendingCommand = pending
    repository.stubProcessError = error
    repository.shouldFailLoadPending = shouldFailLoadPending
    repository.shouldFailUpdatePending = shouldFailUpdatePending
    repository.stubUsageLoadResult = usageLoadResult
    repository.shouldFailLoadUsage = shouldFailLoadUsage
    return repository
}


final class StubAuthStore: AuthStore, @unchecked Sendable {

    private let auth: Auth?
    init(auth: Auth?) { self.auth = auth }

    func loadCurrentAuth() -> Auth? { return self.auth }
    func saveAuth(_ auth: Auth) { }
    func removeAuth() { }
}
