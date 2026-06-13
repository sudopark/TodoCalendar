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
    
    func processCommand(_ commandText: String) -> AnyPublisher<AIJob, any Error>
    
    func processConfirmCommand(_ action: AIConfirmCommandAction) -> AnyPublisher<AIJob, any Error>

    func rejectConfirmCommand(_ action: AIConfirmCommandAction)

    func restoreCommandifNeed() -> AnyPublisher<AIJob, any Error>

    func handleJobFinishNotification(_ jobId: String)
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
    
    public func processCommand(_ commandText: String) -> AnyPublisher<AIJob, any Error> {
        
        let timeZone = self.currentIANATimeZone(); let repository = self.repository

        let makeJob: some Publisher<String, any Error> = Publishers.create(do: {
            let jobId = try await repository.processCommand(commandText, timeZone: timeZone)
            try? await repository.updateProcessingAICommand(
                .init(jobId: jobId, isConfirmJob: false)
            )
            return jobId
        })
        
        let waitJobUntilFinish = makeJob.flatMap { [weak self] jobId in
            return self?.checkJob(jobId) ?? Empty().eraseToAnyPublisher()
        }
        
        return waitJobUntilFinish
            .handleClearProcessingCommand(repository)
            .eraseToAnyPublisher()
    }
    
    public func processConfirmCommand(_ action: AIConfirmCommandAction) -> AnyPublisher<AIJob, any Error> {

        let timeZone = self.currentIANATimeZone(); let repository = self.repository

        let makeConfirmJob: some Publisher<String, any Error> = Publishers.create(do: {
            let jobId = try await repository.processConfirmCommand(action, timeZone: timeZone)
            try? await repository.updateProcessingAICommand(
                .init(jobId: jobId, isConfirmJob: true)
            )
            return jobId
        })
        
        let waitUntilFinish = makeConfirmJob.flatMap { [weak self] jobId in
            return self?.checkJob(jobId) ?? Empty().eraseToAnyPublisher()
        }
        
        return waitUntilFinish
            .handleClearProcessingCommand(repository)
            .eraseToAnyPublisher()
    }
    
    public func rejectConfirmCommand(_ action: AIConfirmCommandAction) {
        let repository = self.repository
        // 서버 거부 API(Functions#243)는 미구현 — 준비 전까지 fire-and-forget.
        Task { try? await repository.rejectConfirmCommand(action) }
    }

    public func handleJobFinishNotification(_ jobId: String) {
        self.subject.jobFinishEvent.send(jobId)
    }
    
    private func checkJob(_ jobId: String) -> AnyPublisher<AIJob, any Error> {
        
        let refreshWithPolling = self.polling()
        let refreshAfterPushReceive = self.subject.jobFinishEvent
            .filter { $0 == jobId }
            .map { _ in }
        
        let refreshTrigger = Publishers.Merge(refreshWithPolling, refreshAfterPushReceive)
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
    
    public func restoreCommandifNeed() -> AnyPublisher<AIJob, any Error> {
        
        let processingCmd = self.loadProcessingCommand()
        
        let restorePolling = processingCmd.flatMap { [weak self] cmd in
            guard let self, let cmd
            else {
                return Empty<AIJob, any Error>().eraseToAnyPublisher()
            }
            
            return self.checkJob(cmd.jobId)
        }
        
        return restorePolling
            .handleClearProcessingCommand(repository)
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
        
        let handleOutput: (AIJob) -> Void = { job in
            guard job.isFinish else { return }
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
