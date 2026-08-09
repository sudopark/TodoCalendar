//
//  AICommandUsecase.swift
//  Domain
//
//  Created by sudo.park on 5/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


public protocol AICommandUsecase: AnyObject, Sendable {
    
    func processCommand(_ commandText: String) -> AnyPublisher<AICommandProcessing, any Error>

    func processInterpretCommand(
        text: String,
        additionalInstruction: String?,
        inputSource: AICommandInputSource
    ) -> AnyPublisher<AICommandProcessing, any Error>

    func processConfirmCommand(_ action: AIConfirmCommandAction) -> AnyPublisher<AICommandProcessing, any Error>

    func rejectConfirmCommand(_ action: AIConfirmCommandAction)

    func cancelOngoingCommand(_ jobId: String)

    func clearProcessingCommandRecord() async

    func restoreCommandifNeed() -> AnyPublisher<AICommandProcessing?, any Error>

    func refreshJobStatus(_ jobId: String)
}


// MARK: - AICommandUsecaseImple

public final class AICommandUsecaseImple: AICommandUsecase, @unchecked Sendable {
    
    public struct PollingPolicy {
        let checkInterval: TimeInterval
        let totalTimeout: TimeInterval
        
        public static var `default`: PollingPolicy {
            return .init(checkInterval: 10, totalTimeout: 10*60)
        }
        
        var totalTimeoutMsInt: Int { (totalTimeout * 1000) |> Int.init }
    }
    
    private let repository: any AICommandRepository
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let pollingPolicy: PollingPolicy
    public init(
        repository: any AICommandRepository,
        calendarSettingUsecase: any CalendarSettingUsecase,
        pollingPolicy: PollingPolicy = .default
    ) {
        self.repository = repository
        self.calendarSettingUsecase = calendarSettingUsecase
        self.pollingPolicy = pollingPolicy
        
        self.internalBind()
    }
    
    private struct Subject {
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let jobFinishEvent = PassthroughSubject<String, Never>()
    }
    private let subject = Subject()
    private var cancelBag = Set<AnyCancellable>()

    private func internalBind() {
        self.calendarSettingUsecase.currentTimeZone
            .sink(receiveValue: { [weak self] timeZone in
                self?.subject.timeZone.send(timeZone)
            })
            .store(in: &self.cancelBag)
    }
}


// MARK: - process command

extension AICommandUsecaseImple {
    
    public func processCommand(_ commandText: String) -> AnyPublisher<AICommandProcessing, any Error> {

        let timeZone = self.currentIANATimeZone(); let repository = self.repository

        let makeJob: some Publisher<String, any Error> = Publishers.create(do: {
            let jobId = try await repository.processCommand(commandText, timeZone: timeZone)
            try? await repository.updateProcessingAICommand(
                .init(jobId: jobId, isConfirmJob: false)
            )
            return jobId
        })

        return self.waitJobUntilFinish(makeJob)
    }

    public func processInterpretCommand(
        text: String,
        additionalInstruction: String?,
        inputSource: AICommandInputSource
    ) -> AnyPublisher<AICommandProcessing, any Error> {

        let timeZone = self.currentIANATimeZone(); let repository = self.repository

        let makeJob: some Publisher<String, any Error> = Publishers.create(do: {
            let jobId = try await repository.processInterpretCommand(
                text: text,
                additionalInstruction: additionalInstruction,
                inputSource: inputSource,
                timeZone: timeZone
            )
            try? await repository.updateProcessingAICommand(
                .init(jobId: jobId, isConfirmJob: false)
            )
            return jobId
        })

        return self.waitJobUntilFinish(makeJob)
    }

    public func processConfirmCommand(_ action: AIConfirmCommandAction) -> AnyPublisher<AICommandProcessing, any Error> {

        let timeZone = self.currentIANATimeZone(); let repository = self.repository

        let makeConfirmJob: some Publisher<String, any Error> = Publishers.create(do: {
            let jobId = try await repository.processConfirmCommand(action, timeZone: timeZone)
            try? await repository.updateProcessingAICommand(
                .init(jobId: jobId, isConfirmJob: true)
            )
            return jobId
        })

        return self.waitJobUntilFinish(makeConfirmJob)
    }

    private func waitJobUntilFinish(
        _ makeJobId: some Publisher<String, any Error>,
        immediateCheck: Bool = false
    ) -> AnyPublisher<AICommandProcessing, any Error> {

        let repository = self.repository
        return makeJobId
            .flatMap { [weak self] jobId -> AnyPublisher<AICommandProcessing, any Error> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.checkJob(jobId, immediateCheck: immediateCheck)
                    .handleClearProcessingCommand(repository)
                    .map { AICommandProcessing.job($0) }
                    .prepend(.started(jobId: jobId))
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    public func rejectConfirmCommand(_ action: AIConfirmCommandAction) {
        let repository = self.repository
        Task {
            try? await repository.rejectConfirmCommand(action)
            try? await repository.clearProcessingAICommand()
        }
    }

    public func cancelOngoingCommand(_ jobId: String) {
        let repository = self.repository
        Task {
            try? await repository.cancelCommand(jobId)
            try? await repository.clearProcessingAICommand()
        }
    }

    public func clearProcessingCommandRecord() async {
        try? await self.repository.clearProcessingAICommand()
    }

    public func refreshJobStatus(_ jobId: String) {
        self.subject.jobFinishEvent.send(jobId)
    }
    
    private func checkJob(
        _ jobId: String,
        immediateCheck: Bool = false
    ) -> AnyPublisher<AIJob, any Error> {

        let refreshWithPolling = self.polling()
        let refreshAfterPushReceive = self.subject.jobFinishEvent
            .filter { $0 == jobId }
            .map { _ in }

        let refreshTrigger = Publishers.Merge(refreshWithPolling, refreshAfterPushReceive)
            .prepend(immediateCheck ? [()] : [])
        let refreshJob = refreshTrigger.map { [weak self] in
            guard let self = self else { return Empty<AIJob, any Error>().eraseToAnyPublisher() }
            return self.loadJobWithFilterError(jobId).eraseToAnyPublisher()
        }
        .switchToLatest()
        .share(replay: 1)
        
        let timeout = refreshJob.notFinishJobTimeout(
            self.pollingPolicy.totalTimeoutMsInt
        )
        return Publishers.Merge(
            refreshJob,
            timeout
        )
        .prefixWithInclude(firstMatch: { $0.isFinish })
        .eraseToAnyPublisher()
    }
    
    private func loadJobWithFilterError(_ jobId: String) -> AnyPublisher<AIJob, any Error> {
        let repository = self.repository
        return Publishers.create(do: {
            return try await repository.loadJob(jobId)
        })
        .catch { (error: any Error) in
            switch (error as? ServerErrorModel)?.code {
            case .forbidden, .notFound:
                return Fail<AIJob, any Error>(error: error).eraseToAnyPublisher()
            default:
                return Empty<AIJob, any Error>().eraseToAnyPublisher()
            }
        }
        .eraseToAnyPublisher()
    }
}


// MARK: - restore command

extension AICommandUsecaseImple {
    
    public func restoreCommandifNeed() -> AnyPublisher<AICommandProcessing?, any Error> {

        let processingCmd = self.loadProcessingCommand()

        return processingCmd
            .flatMap { [weak self] cmd -> AnyPublisher<AICommandProcessing?, any Error> in
                guard let self, let cmd
                else {
                    return Just<AICommandProcessing?>(nil)
                        .setFailureType(to: (any Error).self)
                        .eraseToAnyPublisher()
                }

                let restoredJobId = Just(cmd.jobId).setFailureType(to: (any Error).self)
                return self.waitJobUntilFinish(restoredJobId, immediateCheck: true)
                    .map { Optional($0) }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    private func loadProcessingCommand() -> some Publisher<ProcessingAICommand?, any Error> {
        let repository = self.repository
        return Publishers.create(do: {
            return try await repository.loadProcessingAICommand()
        })
    }
}

extension AICommandUsecaseImple {
    
    private func currentIANATimeZone() -> String {
        return (self.subject.timeZone.value ?? .current).identifier
    }
    
    private func polling() -> some Publisher<Void, Never> {
        return Timer
            .publish(every: self.pollingPolicy.checkInterval, on: RunLoop.main, in: .common)
            .autoconnect()
            .map { _ in }
    }
}

private extension Publisher where Output == AIJob, Failure == any Error {
    
    func notFinishJobTimeout(_ intervalMs: Int) -> some Publisher<Output, Failure> {
        
        return self
            .first(where: { $0.isFinish })
            .timeout(
                .milliseconds(intervalMs),
                scheduler: DispatchQueue.main,
                customError: { RuntimeError(key: "timeout", "process command timeout") }
            )
            .flatMap { _ in
                return Empty<AIJob, any Error>().eraseToAnyPublisher()
            }
    }
    
    func handleClearProcessingCommand(
        _ repository: AICommandRepository
    ) -> some Publisher<AIJob, Failure> {
        
        // confirm은 종료가 아니라 유저 응답 대기다. 여기서 지우면 콜드스타트 복원 근거가
        // 사라져 대기 중이던 confirm이 유실된다 — 정리는 응답(confirm/decline/중지)이 한다.
        let handleOutput: (AIJob) -> Void = { job in
            guard job.isFinish, job.status != .confirm else { return }
            Task { try await repository.clearProcessingAICommand() }
        }
        
        let handleError: (Subscribers.Completion<any Error>) -> Void = { completion in
            guard case .failure = completion else { return }
            Task { try await repository.clearProcessingAICommand() }
        }
        
        return self.handleEvents(
            receiveOutput: handleOutput,
            receiveCompletion: handleError
        )
    }
}
