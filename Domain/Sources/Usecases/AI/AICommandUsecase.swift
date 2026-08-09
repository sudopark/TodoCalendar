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

    func cancelOngoingCommand()

    func clearProcessingCommandRecord() async

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
    private let ongoingCommand = OngoingCommandTracker()
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

        let creation = self.makeJob(isConfirmJob: false) {
            try await repository.processCommand(commandText, timeZone: timeZone)
        }

        return self.waitJobUntilFinish(creation)
    }

    public func processConfirmCommand(_ action: AIConfirmCommandAction) -> AnyPublisher<AIJob, any Error> {

        let timeZone = self.currentIANATimeZone(); let repository = self.repository

        let creation = self.makeJob(isConfirmJob: true) {
            try await repository.processConfirmCommand(action, timeZone: timeZone)
        }

        return self.waitJobUntilFinish(creation)
    }

    // job 생성은 구독 수명에서 떼어낸다 — 시트가 닫히거나 중지로 구독이 끊겨도 jobId를
    // 받아내야 서버에 취소를 보낼 수 있다. 구독이 끊긴 채 생성만 성공하면 서버 job은
    // 계속 돌고 취소 요청은 갈 곳을 잃는다 (#795).
    // unstructured Task라 구독 취소는 결과 대기만 끊고 생성 자체는 완주한다.
    private func makeJob(
        isConfirmJob: Bool,
        _ create: @escaping @Sendable () async throws -> String
    ) -> AnyPublisher<JobCreationResult, any Error> {

        let repository = self.repository; let ongoing = self.ongoingCommand
        return Deferred {
            ongoing.beginCreating()
            let creation = Task { () throws -> JobCreationResult in
                do {
                    let jobId = try await create()
                    try? await repository.updateProcessingAICommand(
                        .init(jobId: jobId, isConfirmJob: isConfirmJob)
                    )
                    switch ongoing.attachJob(jobId) {
                    case .tracked:
                        return .created(jobId: jobId)
                    case .cancelNow:
                        await repository.cancelJobAndClearRecord(jobId)
                        return .canceledWhileCreating
                    }
                } catch {
                    ongoing.clear()
                    throw error
                }
            }
            let waitCreation: some Publisher<JobCreationResult, any Error> = Publishers
                .create(do: { try await creation.value })
            return waitCreation
        }
        .eraseToAnyPublisher()
    }

    private func waitJobUntilFinish(
        _ jobCreation: AnyPublisher<JobCreationResult, any Error>
    ) -> AnyPublisher<AIJob, any Error> {

        return jobCreation
            .flatMap { [weak self] creation -> AnyPublisher<AIJob, any Error> in
                // 생성 도중 중지된 job은 취소가 이미 나갔다 — 폴링을 시작하지 않는다.
                guard let self, case .created(let jobId) = creation
                else { return Empty().eraseToAnyPublisher() }
                return self.checkJob(jobId)
            }
            .handleClearProcessingCommand(self.repository, self.ongoingCommand)
            .eraseToAnyPublisher()
    }

    public func rejectConfirmCommand(_ action: AIConfirmCommandAction) {
        // 서버 거부 API(Functions#243) 미구현 — 준비 전까지 fire-and-forget.
        // 거부는 confirm 대기의 종착점이라 로컬 기록도 함께 정리한다 (cancelOngoingCommand와 대칭).
        // 안 지우면 거부한 confirm이 다음 복원에 되살아나고, 앱 밖 진입점도 영구 차단된다.
        self.ongoingCommand.clear()
        let repository = self.repository
        Task {
            try? await repository.rejectConfirmCommand(action)
            try? await repository.clearProcessingAICommand()
        }
    }

    // 취소 대상 판정은 호출자가 아니라 여기서 한다 — 호출자는 jobId를 모르거나(첫 조회 전)
    // 이미 끝난 job을 들고 있을 수 있다. 진행 중인 게 없으면 아무것도 하지 않는다 (#795).
    // fire-and-forget — 호출 시점에 orchestration이 이미 구독을 끊고 idle로 보냈다.
    // 서버의 CANCELED 통보를 클라가 소비하는 경로는 없다 (clear 전에 앱이 죽어
    // 잔여 레코드가 restore되는 경우만 예외 — AIJob.Status.canceled가 이를 방어한다).
    public func cancelOngoingCommand() {
        guard let jobId = self.ongoingCommand.requestCancel() else { return }
        let repository = self.repository
        Task {
            await repository.cancelJobAndClearRecord(jobId)
        }
    }

    // 로그아웃 정리 전용 — 서버 job은 그대로 두고 로컬 복원 근거만 지운다.
    // 남겨두면 재로그인 시 restoreCommandifNeed가 죽은 job을 이어받아 다시 폴링한다.
    public func clearProcessingCommandRecord() async {
        self.ongoingCommand.clear()
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
    
    public func restoreCommandifNeed() -> AnyPublisher<AIJob?, any Error> {

        let processingCmd = self.loadProcessingCommand()

        return processingCmd
            .flatMap { [weak self] cmd -> AnyPublisher<AIJob?, any Error> in
                guard let self, let cmd else { return Self.noRestoredJob }
                // 복원한 job도 진행 중으로 등록해야 이후 중지가 서버까지 간다
                guard case .tracked = self.ongoingCommand.attachJob(cmd.jobId)
                else {
                    return self.cancelRestoredJob(cmd.jobId)
                }

                return self.checkJob(cmd.jobId, immediateCheck: true)
                    .handleClearProcessingCommand(self.repository, self.ongoingCommand)
                    .map { Optional($0) }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private static var noRestoredJob: AnyPublisher<AIJob?, any Error> {
        return Just<AIJob?>(nil)
            .setFailureType(to: (any Error).self)
            .eraseToAnyPublisher()
    }

    // 복원 도중 중지가 들어온 경우 — 폴링을 시작하지 않고 취소만 집행한다
    private func cancelRestoredJob(_ jobId: String) -> AnyPublisher<AIJob?, any Error> {
        let repository = self.repository
        Task {
            await repository.cancelJobAndClearRecord(jobId)
        }
        return Self.noRestoredJob
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

// MARK: - OngoingCommandTracker

private enum JobCreationResult {
    case created(jobId: String)
    case canceledWhileCreating
}



// 진행 중 command의 취소 대상 여부를 한 곳에서 소유한다. 중지 요청이 job 생성 응답보다
// 먼저 도착할 수 있어(POST in-flight), 그 경우 취소를 예약했다가 생성 직후 집행한다 (#795).
private final class OngoingCommandTracker: @unchecked Sendable {

    enum AttachResult {
        case tracked
        case cancelNow
    }

    private enum State {
        case none
        case creating(cancelRequested: Bool)
        case ongoing(jobId: String)
    }

    private let lock = NSLock()
    private var state: State = .none

    func beginCreating() {
        self.lock.lock(); defer { self.lock.unlock() }
        self.state = .creating(cancelRequested: false)
    }

    func attachJob(_ jobId: String) -> AttachResult {
        self.lock.lock(); defer { self.lock.unlock() }
        if case .creating(let cancelRequested) = self.state, cancelRequested {
            self.state = .none
            return .cancelNow
        }
        self.state = .ongoing(jobId: jobId)
        return .tracked
    }

    // 지금 취소해야 할 jobId. nil이면 취소할 대상이 없거나(none) 생성 완료 후로 예약됐다.
    func requestCancel() -> String? {
        self.lock.lock(); defer { self.lock.unlock() }
        switch self.state {
        case .ongoing(let jobId):
            self.state = .none
            return jobId
        case .creating:
            self.state = .creating(cancelRequested: true)
            return nil
        case .none:
            return nil
        }
    }

    func clear() {
        self.lock.lock(); defer { self.lock.unlock() }
        self.state = .none
    }
}


private extension AICommandRepository {

    func cancelJobAndClearRecord(_ jobId: String) async {
        try? await self.cancelCommand(jobId)
        try? await self.clearProcessingAICommand()
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
        _ repository: AICommandRepository,
        _ ongoingCommand: OngoingCommandTracker
    ) -> some Publisher<AIJob, Failure> {

        // confirm은 종료가 아니라 유저 응답 대기다. 여기서 지우면 콜드스타트 복원 근거가
        // 사라져 대기 중이던 confirm이 유실된다 — 정리는 응답(confirm/decline/중지)이 한다.
        let handleOutput: (AIJob) -> Void = { job in
            guard job.isFinish, job.status != .confirm else { return }
            ongoingCommand.clear()
            Task { try await repository.clearProcessingAICommand() }
        }

        let handleError: (Subscribers.Completion<any Error>) -> Void = { completion in
            guard case .failure = completion else { return }
            ongoingCommand.clear()
            Task { try await repository.clearProcessingAICommand() }
        }
        
        return self.handleEvents(
            receiveOutput: handleOutput,
            receiveCompletion: handleError
        )
    }
}
