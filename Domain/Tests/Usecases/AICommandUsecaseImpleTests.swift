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
    private var stubRepository = PrivateStubRepository()
    
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
            checkInterval: 0.1,
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
        let expect = expectConfirm("커맨드 처리 정상케이스 동선: 작업 생성, 대기 이후 결과 반환 - \(String(describing: finalJob.status))")
        expect.timeout = .seconds(5)
        let usecase = self.makeUsecase(customStubLoadJobs: [
            .dummyPendingJob, .dummyPendingJob,
            .dummyRunningJob, .dummyRunningJob,
            finalJob
        ])
        
        // when
        let processing = usecase.processCommand("cmd")
        let job = try await self.firstOutput(expect, for: processing)
        
        // then
        #expect(job?.isFinish == true)
        #expect(job?.status == finalJob.status)
    }

    @Test func usecase_whenProcessCommand_checkIsFinishWithPolling() async throws {
        // given
        let expect = expectConfirm("커맨드 처리시 주기적으로 작업상태 폴링해서 완료 여부 판단")
        expect.timeout = .seconds(5)
        let usecase = self.makeUsecase()
        
        // when
        let processing = usecase.processCommand("cmd")
        let job = try await self.firstOutput(expect, for: processing)
        
        // then
        #expect(job?.isFinish == true)
    }
    
    // 커맨드 처리시 fcm 메세지 받으면 작업상태 확인해서 완료 정보 반환
    @Test func usecase_whenReceiveJobFinishNotification_loadFinishedJob() async throws {
        // given
        let expect = expectConfirm("커맨드 처리시 fcm 메세지 받으면 작업상태 확인해서 완료 정보 반환")
        expect.timeout = .seconds(5)
        let policy = AICommandUsecaseImple.PollingPolicy(
            checkInterval: 1,
            totalTimeout: 10
        )
        let usecase = self.makeUsecase(customPollingPolicy: policy)
        self.stubRepository.loadJobMocking = .dummyRunningJob
        
        // when
        let processing = usecase.processCommand("cmd")
        let job = try await self.firstOutput(expect, for: processing) {
            
            try await Task.sleep(for: .milliseconds(10))
            self.stubRepository.loadJobMocking = .dummyConfirmJob
            
            usecase.handleJobFinishNotification("some_job")
        }
        
        // then
        #expect(job?.isFinish == true)
    }
    
    // 커맨드 처리시 에러 발생해도 폴링 유지
    @Test func usecase_whenProcessCommand_ignoreErrorDuringLoad() async throws {
        // given
        let expect = expectConfirm("커맨드 처리시 에러 발생해도 폴링 유지")
        expect.timeout = .seconds(5)
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
        let job = try await self.firstOutput(expect, for: processing)
        
        // then
        #expect(job?.isFinish == true)
    }
    
    // 커맨드 처리시 forbidden, notFound 에러 수신시 폴링 중지
    @Test(arguments: [ServerErrorModel.dummy(.forbidden), .dummy(.notFound)])
    func usecase_whenProcessCommand_stopCheckAndThrowError(_ reason: ServerErrorModel) async throws {
        // given
        let expect = expectConfirm("커맨드 처리시 forbidden, notFound 에러 수신시 폴링 중지")
        expect.timeout = .seconds(5)
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
    }
    
    // 커맨드 처리 - 완료여부 폴링 작업 전체 타임아웃 초과시 에러 처리
    @Test func usecase_whenProcessCommandTakeTooLong_timeout() async throws {
        // given
        let expect = expectConfirm("커맨드 처리 - 완료여부 폴링 작업 전체 타임아웃 초과시 에러 처리")
        expect.timeout = .seconds(5)
        let usecase = self.makeUsecase(
            customStubLoadJobs: Array(repeating: .dummyRunningJob, count: 4000)
        )
        
        // when
        let processing = usecase.processCommand("cmd")
        let fail = try await self.failure(expect, for: processing)
        
        // then
        #expect(fail != nil)
        #expect((fail as? RuntimeError)?.key == "timeout")
    }
    
    // 커맨드 요청부터 실패한경우 -> 에러
    @Test func usecase_processCommandFail() async throws {
        // given
        let expect = expectConfirm("커맨드 요청부터 실패한경우 -> 에러")
        expect.timeout = .seconds(5)
        let usecase = self.makeUsecase(shouldFailMakeJob: true)
        
        // when
        let processing = usecase.processCommand("cmd")
        let fail = try await self.failure(expect, for: processing)
        
        // then
        #expect(fail != nil)
    }
}


// MARK: - process confirm command

extension AICommandUsecaseImpleTests {

    @Test(arguments: [AIJob.dummyDoneJob, .dummyFailJob, .dummyConfirmJob])
    func usecase_processConfirmCommand(_ finalJob: AIJob) async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 처리 정상케이스 동선: 작업 생성, 대기 이후 결과 반환 - \(String(describing: finalJob.status))")
        expect.timeout = .seconds(5)
        let usecase = self.makeUsecase(customStubLoadJobs: [
            .dummyPendingJob, .dummyPendingJob,
            .dummyRunningJob, .dummyRunningJob,
            finalJob
        ])

        // when
        let processing = usecase.processConfirmCommand(.init())
        let job = try await self.firstOutput(expect, for: processing)

        // then
        #expect(job?.isFinish == true)
        #expect(job?.status == finalJob.status)
    }

    @Test func usecase_whenProcessConfirmCommand_checkIsFinishWithPolling() async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 처리시 주기적으로 작업상태 폴링해서 완료 여부 판단")
        expect.timeout = .seconds(5)
        let usecase = self.makeUsecase()

        // when
        let processing = usecase.processConfirmCommand(.init())
        let job = try await self.firstOutput(expect, for: processing)

        // then
        #expect(job?.isFinish == true)
    }

    // 컨펌 커맨드 처리시 fcm 메세지 받으면 작업상태 확인해서 완료 정보 반환
    @Test func usecase_whenReceiveJobFinishNotification_loadFinishedConfirmJob() async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 처리시 fcm 메세지 받으면 작업상태 확인해서 완료 정보 반환")
        expect.timeout = .seconds(5)
        let policy = AICommandUsecaseImple.PollingPolicy(
            checkInterval: 1,
            totalTimeout: 10
        )
        let usecase = self.makeUsecase(customPollingPolicy: policy)
        self.stubRepository.loadJobMocking = .dummyRunningJob

        // when
        let processing = usecase.processConfirmCommand(.init())
        let job = try await self.firstOutput(expect, for: processing) {

            try await Task.sleep(for: .milliseconds(10))
            self.stubRepository.loadJobMocking = .dummyDoneJob

            usecase.handleJobFinishNotification("some_job")
        }

        // then
        #expect(job?.isFinish == true)
    }

    // 컨펌 커맨드 처리시 에러 발생해도 폴링 유지
    @Test func usecase_whenProcessConfirmCommand_ignoreErrorDuringLoad() async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 처리시 에러 발생해도 폴링 유지")
        expect.timeout = .seconds(5)
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
        let job = try await self.firstOutput(expect, for: processing)

        // then
        #expect(job?.isFinish == true)
    }

    // 컨펌 커맨드 처리시 forbidden, notFound 에러 수신시 폴링 중지
    @Test(arguments: [ServerErrorModel.dummy(.forbidden), .dummy(.notFound)])
    func usecase_whenProcessConfirmCommand_stopCheckAndThrowError(_ reason: ServerErrorModel) async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 처리시 forbidden, notFound 에러 수신시 폴링 중지")
        expect.timeout = .seconds(5)
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
    }

    // 컨펌 커맨드 처리 - 완료여부 폴링 작업 전체 타임아웃 초과시 에러 처리
    @Test func usecase_whenProcessConfirmCommandTakeTooLong_timeout() async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 처리 - 완료여부 폴링 작업 전체 타임아웃 초과시 에러 처리")
        expect.timeout = .seconds(5)
        let usecase = self.makeUsecase(
            customStubLoadJobs: Array(repeating: .dummyRunningJob, count: 4000)
        )

        // when
        let processing = usecase.processConfirmCommand(.init())
        let fail = try await self.failure(expect, for: processing)

        // then
        #expect(fail != nil)
        #expect((fail as? RuntimeError)?.key == "timeout")
    }

    // 컨펌 커맨드 요청부터 실패한경우 -> 에러
    @Test func usecase_processConfirmCommandFail() async throws {
        // given
        let expect = expectConfirm("컨펌 커맨드 요청부터 실패한경우 -> 에러")
        expect.timeout = .seconds(5)
        let usecase = self.makeUsecase(shouldFailMakeConfirmJob: true)

        // when
        let processing = usecase.processConfirmCommand(.init())
        let fail = try await self.failure(expect, for: processing)

        // then
        #expect(fail != nil)
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

private final class PrivateStubRepository: AICommandRepository, @unchecked Sendable {
    
    var shouldFailProcessCommand: Bool = false
    func processCommand(_ commandText: String, timeZone: String) async throws -> String {
        guard !self.shouldFailProcessCommand
        else {
            throw RuntimeError("not imple")
        }
        return "some_job"
    }

    var shouldFailProcessConfirmCommand: Bool = false
    func processConfirmCommand(_ action: AIConfirmCommandAction, timeZone: String) async throws -> String {
        guard !self.shouldFailProcessConfirmCommand
        else {
            throw RuntimeError("not imple")
        }
        return "some_job"
    }
    
    
    var stubLoadJobs: [Result<AIJob, any Error>] = []
    var loadJobMocking: AIJob?
    func loadJob(_ jobId: String) async throws -> AIJob {
        
        if let mocking = self.loadJobMocking {
            return mocking
        }
        
        if self.stubLoadJobs.isEmpty {
            throw RuntimeError("failed")
        }
        
        let first = self.stubLoadJobs.removeFirst()
        switch first {
        case .success(let job): return job
        case .failure(let error): throw error
        }
    }
    
    func loadUsage() async throws -> AIAgentUsage {
        throw RuntimeError("not imple")
    }
}
