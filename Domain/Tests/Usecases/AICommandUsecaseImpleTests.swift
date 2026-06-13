//
//  AICommandUsecaseImpleTests.swift
//  Domain
//
//  Created by sudo.park on 5/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import Domain


final class AICommandUsecaseImpleTests: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = []
    private var stubRepository = BaseStubAICommandRepository()
    
    private func makeUsecase(
        shouldFailMakeJob: Bool = false,
        shouldFailMakeConfirmJob: Bool = false,
        customStubLoadJobs: [AIJob]? = nil,
        customStubLoadJobAsResult: [Result<AIJob, any Error>]? = nil,
        shouldFailLoadJobWithError: ServerErrorModel? = nil,
        customPollingPolicy: AICommandUsecaseImple.PollingPolicy? = nil
    ) -> AICommandUsecaseImple {

        stubRepository.shouldFailProcessCommand = shouldFailMakeJob
        stubRepository.shouldFailProcessConfirmCommand = shouldFailMakeConfirmJob
        let jobs = customStubLoadJobs ?? [
            .dummyPendingJob, .dummyRunningJob, .dummyRunningJob, .dummyDoneJob
        ]
        stubRepository.stubLoadJobs = customStubLoadJobAsResult
        ?? jobs.map { .success($0) }
        
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.selectTimeZone(TimeZone(abbreviation: "KST")!)
        
        let policy = AICommandUsecaseImple.PollingPolicy(
            checkInterval: 0.05,
            totalTimeout: 3
        )
        
        return AICommandUsecaseImple(
            repository: stubRepository,
            calendarSettingUsecase: calendarSettingUsecase,
            pollingPolicy: customPollingPolicy ?? policy
        )
    }
}


// MARK: - process commmand

extension AICommandUsecaseImpleTests {
    
    @Test(arguments: [AIJob.dummyDoneJob, .dummyFailJob, .dummyConfirmJob])
    func usecase_processCommand(_ finalJob: AIJob) async throws {
        // given
        let expect = expectConfirm("커맨드 처리 정상케이스 동선: 진행상태 모두 방출 후 완료 - \(String(describing: finalJob.status))")
        expect.count = 5
        expect.timeout = .seconds(1)
        let usecase = self.makeUsecase(customStubLoadJobs: [
            .dummyPendingJob, .dummyPendingJob,
            .dummyRunningJob, .dummyRunningJob,
            finalJob
        ])
        
        // when
        let processing = usecase.processCommand("cmd")
        let jobs = try await self.outputs(expect, for: processing)
        
        // then
        let statuses = jobs.map { $0.status }
        #expect(statuses == [.pending, .pending, .running, .running, finalJob.status])
        #expect(jobs.last?.isFinish == true)
    }

    @Test func usecase_whenProcessCommand_checkIsFinishWithPolling() async throws {
        // given
        let expect = expectConfirm("커맨드 처리시 폴링으로 작업 진행상태 모두 방출 후 완료")
        expect.count = 4
        expect.timeout = .seconds(1)
        let usecase = self.makeUsecase()
        
        // when
        let processing = usecase.processCommand("cmd")
        let jobs = try await self.outputs(expect, for: processing)
        
        // then
        let statuses = jobs.map { $0.status }
        #expect(statuses == [.pending, .running, .running, .done])
        #expect(jobs.last?.isFinish == true)
        
        let processingCmd = try await self.stubRepository.loadProcessingAICommand()
        #expect(processingCmd == nil)
    }
    
    // 커맨드 처리시 fcm 메세지 받으면 작업상태 확인해서 완료 정보 반환
    @Test func usecase_whenReceiveJobFinishNotification_loadFinishedJob() async throws {
        // given
        let expect = expectConfirm("커맨드 처리시 fcm 메세지 받으면 작업상태 확인해서 완료 정보 반환")
        expect.timeout = .seconds(1)
        let policy = AICommandUsecaseImple.PollingPolicy(
            checkInterval: 3,
            totalTimeout: 10
        )
        let usecase = self.makeUsecase(customPollingPolicy: policy)
        self.stubRepository.loadJobMocking = .success(.dummyRunningJob)
        
        // when
        let processing = usecase.processCommand("cmd")
        let jobs = try await self.outputs(expect, for: processing) {
            
            try await Task.sleep(for: .milliseconds(10))
            self.stubRepository.loadJobMocking = .success(.dummyConfirmJob)
            
            usecase.handleJobFinishNotification("some_job")
        }
        
        // then
        #expect(jobs.last?.isFinish == true)
        #expect(jobs.last?.status == .confirm)
    }
    
    // 커맨드 처리시 에러 발생해도 폴링 유지
    @Test func usecase_whenProcessCommand_ignoreErrorDuringLoad() async throws {
        // given
        let expect = expectConfirm("커맨드 처리시 에러는 건너뛰고 성공 응답만 진행상태로 방출")
        expect.count = 3
        expect.timeout = .seconds(1)
        let usecase = self.makeUsecase(
            customStubLoadJobAsResult: [
                .success(.dummyPendingJob),
                .success(.dummyRunningJob),
                .failure(RuntimeError("failed")),
                .failure(RuntimeError("failed")),
                .success(.dummyDoneJob)
            ]
        )
        
        // when
        let processing = usecase.processCommand("cmd")
        let jobs = try await self.outputs(expect, for: processing)
        
        // then
        let statuses = jobs.map { $0.status }
        #expect(statuses == [.pending, .running, .done])
        #expect(jobs.last?.isFinish == true)
    }
    
    // 커맨드 처리시 forbidden, notFound 에러 수신시 폴링 중지
    @Test(arguments: [ServerErrorModel.dummy(.forbidden), .dummy(.notFound)])
    func usecase_whenProcessCommand_stopCheckAndThrowError(_ reason: ServerErrorModel) async throws {
        // given
        let expect = expectConfirm("커맨드 처리시 forbidden, notFound 에러 수신시 폴링 중지")
        expect.timeout = .seconds(1)
        let usecase = self.makeUsecase(
            customStubLoadJobAsResult: [
                .success(.dummyPendingJob),
                .success(.dummyRunningJob),
                .failure(reason),
            ]
        )
        
        // when
        let processing = usecase.processCommand("cmd")
        let fail = try await self.failure(expect, for: processing)
        
        // then
        #expect(fail != nil)
        
        let processingCmd = try await self.stubRepository.loadProcessingAICommand()
        #expect(processingCmd == nil)
    }
    
    // 커맨드 처리 - 완료여부 폴링 작업 전체 타임아웃 초과시 에러 처리
    @Test func usecase_whenProcessCommandTakeTooLong_timeout() async throws {
        // given
        let expect = expectConfirm("커맨드 처리 - 완료여부 폴링 작업 전체 타임아웃 초과시 에러 처리")
        expect.timeout = .seconds(1)
        let usecase = self.makeUsecase(
            customStubLoadJobs: Array(repeating: .dummyRunningJob, count: 400),
            customPollingPolicy: .init(checkInterval: 0.01, totalTimeout: 0.5)
        )
        
        // when
        let processing = usecase.processCommand("cmd")
        let fail = try await self.failure(expect, for: processing)
        
        // then
        #expect(fail != nil)
        #expect((fail as? RuntimeError)?.key == "timeout")
        
        let processingCmd = try await self.stubRepository.loadProcessingAICommand()
        #expect(processingCmd == nil)
    }
    
    // 커맨드 요청부터 실패한경우 -> 에러
    @Test func usecase_processCommandFail() async throws {
        // given
        let expect = expectConfirm("커맨드 요청부터 실패한경우 -> 에러")
        expect.timeout = .seconds(1)
        let usecase = self.makeUsecase(shouldFailMakeJob: true)
        
        // when
        let processing = usecase.processCommand("cmd")
        let fail = try await self.failure(expect, for: processing)
        
        // then
        #expect(fail != nil)
        
        let processingCmd = try await self.stubRepository.loadProcessingAICommand()
        #expect(processingCmd == nil)
    }
}


// MARK: - process confirm command

extension AICommandUsecaseImpleTests {

    @Test(arguments: [AIJob.dummyDoneJob, .dummyFailJob])
    func usecase_processConfirmCommand(_ finalJob: AIJob) async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 처리 정상케이스 동선: 진행상태 모두 방출 후 완료 - \(String(describing: finalJob.status))")
        expect.count = 5
        expect.timeout = .seconds(1)
        let usecase = self.makeUsecase(customStubLoadJobs: [
            .dummyPendingJob, .dummyPendingJob,
            .dummyRunningJob, .dummyRunningJob,
            finalJob
        ])

        // when
        let processing = usecase.processConfirmCommand(.init())
        let jobs = try await self.outputs(expect, for: processing)

        // then
        let statuses = jobs.map { $0.status }
        #expect(statuses == [.pending, .pending, .running, .running, finalJob.status])
        #expect(jobs.last?.isFinish == true)
    }

    @Test func usecase_whenProcessConfirmCommand_checkIsFinishWithPolling() async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 처리시 폴링으로 작업 진행상태 모두 방출 후 완료")
        expect.count = 4
        expect.timeout = .seconds(1)
        let usecase = self.makeUsecase()

        // when
        let processing = usecase.processConfirmCommand(.init())
        let jobs = try await self.outputs(expect, for: processing)

        // then
        let statuses = jobs.map { $0.status }
        #expect(statuses == [.pending, .running, .running, .done])
        #expect(jobs.last?.isFinish == true)
        
        let processingCmd = try await self.stubRepository.loadProcessingAICommand()
        #expect(processingCmd == nil)
    }

    // 컨펌 커맨드 처리시 fcm 메세지 받으면 작업상태 확인해서 완료 정보 반환
    @Test func usecase_whenReceiveJobFinishNotification_loadFinishedConfirmJob() async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 처리시 fcm 메세지 받으면 작업상태 확인해서 완료 정보 반환")
        expect.timeout = .seconds(1)
        let policy = AICommandUsecaseImple.PollingPolicy(
            checkInterval: 3,
            totalTimeout: 10
        )
        let usecase = self.makeUsecase(customPollingPolicy: policy)
        self.stubRepository.loadJobMocking = .success(.dummyRunningJob)

        // when
        let processing = usecase.processConfirmCommand(.init())
        let jobs = try await self.outputs(expect, for: processing) {

            try await Task.sleep(for: .milliseconds(10))
            self.stubRepository.loadJobMocking = .success(.dummyDoneJob)

            usecase.handleJobFinishNotification("some_job")
        }

        // then
        #expect(jobs.last?.isFinish == true)
        #expect(jobs.last?.status == .done)
    }

    // 컨펌 커맨드 처리시 에러 발생해도 폴링 유지
    @Test func usecase_whenProcessConfirmCommand_ignoreErrorDuringLoad() async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 처리시 에러는 건너뛰고 성공 응답만 진행상태로 방출")
        expect.count = 3
        expect.timeout = .seconds(1)
        let usecase = self.makeUsecase(
            customStubLoadJobAsResult: [
                .success(.dummyPendingJob),
                .success(.dummyRunningJob),
                .failure(RuntimeError("failed")),
                .failure(RuntimeError("failed")),
                .success(.dummyDoneJob)
            ]
        )

        // when
        let processing = usecase.processConfirmCommand(.init())
        let jobs = try await self.outputs(expect, for: processing)

        // then
        let statuses = jobs.map { $0.status }
        #expect(statuses == [.pending, .running, .done])
        #expect(jobs.last?.isFinish == true)
    }

    // 컨펌 커맨드 처리시 forbidden, notFound 에러 수신시 폴링 중지
    @Test(arguments: [ServerErrorModel.dummy(.forbidden), .dummy(.notFound)])
    func usecase_whenProcessConfirmCommand_stopCheckAndThrowError(_ reason: ServerErrorModel) async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 처리시 forbidden, notFound 에러 수신시 폴링 중지")
        expect.timeout = .seconds(1)
        let usecase = self.makeUsecase(
            customStubLoadJobAsResult: [
                .success(.dummyPendingJob),
                .success(.dummyRunningJob),
                .failure(reason),
            ]
        )

        // when
        let processing = usecase.processConfirmCommand(.init())
        let fail = try await self.failure(expect, for: processing)

        // then
        #expect(fail != nil)
        
        let processingCmd = try await self.stubRepository.loadProcessingAICommand()
        #expect(processingCmd == nil)
    }

    // 컨펌 커맨드 처리 - 완료여부 폴링 작업 전체 타임아웃 초과시 에러 처리
    @Test func usecase_whenProcessConfirmCommandTakeTooLong_timeout() async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 처리 - 완료여부 폴링 작업 전체 타임아웃 초과시 에러 처리")
        expect.timeout = .seconds(1)
        let usecase = self.makeUsecase(
            customStubLoadJobs: Array(repeating: .dummyRunningJob, count: 400),
            customPollingPolicy: .init(checkInterval: 0.01, totalTimeout: 0.5)
        )

        // when
        let processing = usecase.processConfirmCommand(.init())
        let fail = try await self.failure(expect, for: processing)

        // then
        #expect(fail != nil)
        #expect((fail as? RuntimeError)?.key == "timeout")
        
        let processingCmd = try await self.stubRepository.loadProcessingAICommand()
        #expect(processingCmd == nil)
    }

    // 컨펌 커맨드 요청부터 실패한경우 -> 에러
    @Test func usecase_processConfirmCommandFail() async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 요청부터 실패한경우 -> 에러")
        expect.timeout = .seconds(1)
        let usecase = self.makeUsecase(shouldFailMakeConfirmJob: true)

        // when
        let processing = usecase.processConfirmCommand(.init())
        let fail = try await self.failure(expect, for: processing)

        // then
        #expect(fail != nil)
        
        let processingCmd = try await self.stubRepository.loadProcessingAICommand()
        #expect(processingCmd == nil)
    }
}

// MARK: - rejectConfirmCommand

extension AICommandUsecaseImpleTests {

    @Test func usecase_rejectConfirmCommand_delegatesToRepositoryFireAndForget() async throws {
        // given
        let usecase = self.makeUsecase()
        var action = AIConfirmCommandAction()
        action.confirmToken = "reject-token"

        // when
        usecase.rejectConfirmCommand(action)
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.stubRepository.didRejectConfirmActionToken == "reject-token")
    }
}


// MARK: - restore

extension AICommandUsecaseImpleTests {
    
    // 커맨드 복원: 복원할 커맨드 없음
    @Test func usecase_restoreCommand_notExists() async throws {
        // given
        let expect = expectConfirm("커맨드 복원: 복원할 커맨드 없음")
        expect.count = 0
        let usecase = self.makeUsecase()
        
        // when
        let restore = usecase.restoreCommandifNeed()
        let job = try await self.firstOutput(expect, for: restore)
        
        // then
        #expect(job == nil)
    }
    
    private func makeUsecaseWithProcessingCmd(isConfirm: Bool) async throws -> AICommandUsecaseImple {
        
        let usecase = self.makeUsecase(
            customStubLoadJobs: [
                .dummyRunningJob, .dummyRunningJob, .dummyDoneJob
            ]
        )
        
        let firstJob = if isConfirm {
            usecase.processCommand("cmd").first()
        } else {
            usecase.processConfirmCommand(.init()).first()
        }
        
        let _ = try await firstJob.values.first(where: { _ in true })
        return usecase
    }
    
    // 커맨드 복원: 일반 커맨드 복원 및 폴링
    @Test func usecase_restore_processingCommand() async throws {
        // given
        let expect = expectConfirm("커맨드 복원: 일반 커맨드 복원 및 폴링")
        expect.count = 2
        expect.timeout = .seconds(1)
        let usecase = try await self.makeUsecaseWithProcessingCmd(isConfirm: false)
        
        // when
        let restore = usecase.restoreCommandifNeed()
        let jobs = try await self.outputs(expect, for: restore)
        
        // then
        let statuses = jobs.map { $0.status }
        #expect(statuses == [.running, .done])
        
        let processingCmd = try await self.stubRepository.loadProcessingAICommand()
        #expect(processingCmd == nil)
    }
    
    // 커맨드 복원: confirm 커맨드 복원 및 폴링
    @Test func usecase_restore_processingConfirmCommand() async throws {
        // given
        let expect = expectConfirm("커맨드 복원: confirm 커맨드 복원 및 폴링")
        expect.count = 2
        expect.timeout = .seconds(1)
        let usecase = try await self.makeUsecaseWithProcessingCmd(isConfirm: true)
        
        // when
        let restore = usecase.restoreCommandifNeed()
        let jobs = try await self.outputs(expect, for: restore)
        
        // then
        let statuses = jobs.map { $0.status }
        #expect(statuses == [.running, .done])
        
        let processingCmd = try await self.stubRepository.loadProcessingAICommand()
        #expect(processingCmd == nil)
    }
    
    // 커맨드 복원: 복원 실패
    @Test func usecase_restore_fail() async throws {
        // given
        let expect = expectConfirm("커맨드 복원: 복원 실패")
        expect.count = 2
        expect.timeout = .seconds(1)
        let usecase = try await self.makeUsecaseWithProcessingCmd(isConfirm: false)
        self.stubRepository.loadJobMocking = .failure(
            ServerErrorModel.dummy(.notFound)
        )
        // when
        let restore = usecase.restoreCommandifNeed()
        let error = try await failure(expect, for: restore)
        
        // then
        #expect(error != nil)
        
        let processingCmd = try await self.stubRepository.loadProcessingAICommand()
        #expect(processingCmd == nil)
    }
    
    private func makeUsecaseWithFinishProcessCmd(
        isFail: Bool = false,
        isConfirm: Bool = false
    ) async throws -> AICommandUsecaseImple {
        
        let usecase = self.makeUsecase(
            customStubLoadJobs: [.dummyRunningJob, .dummyDoneJob],
            shouldFailLoadJobWithError: isFail ? .dummy(.notFound) : nil
        )
        
        let firstJob = if isConfirm {
            usecase.processCommand("cmd").first()
        } else {
            usecase.processConfirmCommand(.init()).first()
        }
        
        let _ = try await firstJob.values.first(where: { _ in true })
        return usecase
    }
}

private extension AIJob {
 
    static var dummyPendingJob: AIJob {
        
        let job = AIJob(jobId: "some_job")
            |> \.status .~ .pending
        return job
    }

    static var dummyRunningJob: AIJob {
        return dummyPendingJob
            |> \.status .~ .running
    }

    static var dummyDoneJob: AIJob {
        let result = AIJobResult.DoneResult()
            |> \.text .~ "done"
            |> \.mutations .~ [
                .init(dataType: .todo, operation: .created)
            ]
        return dummyRunningJob
            |> \.status .~ .done
            |> \.result .~ .done(result)
    }

    static var dummyFailJob: AIJob {
        let result = AIJobResult.FailResult()
            |> \.reason .~ "failed"
            |> \.errorCode .~ .agentError
        return dummyRunningJob
            |> \.status .~ .failed
            |> \.result .~ .failed(result)
    }

    static var dummyConfirmJob: AIJob {
        let result = AIJobResult.ConfirmResult()
            |> \.text .~ "confirm need"
            |> \.action .~ .init()
        return dummyRunningJob
            |> \.status .~ .confirm
            |> \.result .~ .confirm(result)
    }
    
}

private extension ServerErrorModel {
    
    static func dummy(_ code: ServerErrorModel.ErrorCode) -> ServerErrorModel {
        return .init()
            |> \.code .~ code
    }
}
