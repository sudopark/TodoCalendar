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

    func cancelOngoingCommand(_ jobId: String)

    func restoreCommandifNeed() -> AnyPublisher<AIJob?, any Error>

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
    
    public func processCommand(_ commandText: String) -> AnyPublisher<AIJob, any Error> {
        
        let timeZone = self.currentIANATimeZone(); let repository = self.repository

        let makeJob: some Publisher<String, any Error> = Publishers.create(do: {
            let jobId = try await repository.processCommand(commandText, timeZone: timeZone)
            try? await repository.updateProcessingAICommand(
                .init(jobId: jobId, isConfirmJob: false)
            )
            return jobId
        })
        
        let waitJobUntilFinish = makeJob
            .flatMap { [weak self] jobId in
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

        let waitUntilFinish = makeConfirmJob
            .flatMap { [weak self] jobId in
                return self?.checkJob(jobId) ?? Empty().eraseToAnyPublisher()
            }

        return waitUntilFinish
            .handleClearProcessingCommand(repository)
            .eraseToAnyPublisher()
    }
    
    public func rejectConfirmCommand(_ action: AIConfirmCommandAction) {
        // 서버 거부 API(Functions#243) 미구현 — 준비 전까지 fire-and-forget.
        // 거부는 confirm 대기의 종착점이라 로컬 기록도 함께 정리한다 (cancelOngoingCommand와 대칭).
        // 안 지우면 거부한 confirm이 다음 복원에 되살아나고, 앱 밖 진입점도 영구 차단된다.
        let repository = self.repository
        Task {
            try? await repository.rejectConfirmCommand(action)
            try? await repository.clearProcessingAICommand()
        }
    }

    public func cancelOngoingCommand(_ jobId: String) {
        // fire-and-forget — 호출 시점에 orchestration이 이미 구독을 끊고 idle로 보냈다.
        // 서버의 CANCELED 통보를 클라가 소비하는 경로는 없다 (clear 전에 앱이 죽어
        // 잔여 레코드가 restore되는 경우만 예외 — AIJob.Status.canceled가 이를 방어한다).
        let repository = self.repository
        Task {
            try? await repository.cancelCommand(jobId)
            try? await repository.clearProcessingAICommand()
        }
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
    
    public func restoreCommandifNeed() -> AnyPublisher<AIJob?, any Error> {

        let processingCmd = self.loadProcessingCommand()

        return processingCmd
            .flatMap { [weak self] cmd -> AnyPublisher<AIJob?, any Error> in
                guard let self, let cmd
                else {
                    return Just<AIJob?>(nil)
                        .setFailureType(to: (any Error).self)
                        .eraseToAnyPublisher()
                }

                return self.checkJob(cmd.jobId, immediateCheck: true)
                    .handleClearProcessingCommand(self.repository)
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
