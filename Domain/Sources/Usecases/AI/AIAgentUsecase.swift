//
//  AIAgentUsecase.swift
//  Domain
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


// MARK: - AIAgentUsecase

public protocol AIAgentUsecase: AnyObject, Sendable {

    var state: AnyPublisher<AIAgentState, Never> { get }
    var usage: AnyPublisher<AIAgentUsage, Never> { get }

    func sendCommand(_ text: String)
    func confirm()
    func decline()

    func reset()
    func restoreIfNeeded()
    func loadUsage()
}


// MARK: - AIAgentUsecaseImple

public final class AIAgentUsecaseImple: AIAgentUsecase, @unchecked Sendable {

    private let commandUsecase: any AICommandUsecase
    private let usageUsecase: any AIAgentUsageUsecase

    public init(
        commandUsecase: any AICommandUsecase,
        usageUsecase: any AIAgentUsageUsecase
    ) {
        self.commandUsecase = commandUsecase
        self.usageUsecase = usageUsecase
    }

    private struct Subject {
        let state = CurrentValueSubject<AIAgentState, Never>(.idle)
    }
    private let subject = Subject()
    private var commandCancellable: AnyCancellable?

    private func startProcessing(_ jobPublisher: AnyPublisher<AIJob, any Error>) {
        self.commandCancellable?.cancel()
        self.commandCancellable = jobPublisher
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.subject.state.send(.failed(reason: nil))
                    }
                },
                receiveValue: { [weak self] job in
                    self?.handleJobResult(job)
                }
            )
    }

    private func handleJobResult(_ job: AIJob) {
        guard job.isFinish else { return }
        // REJECTED는 result.type=CONFIRM이 남아도 status 우선 — confirm 재노출 금지 (복원 시 미동의=초기화)
        if job.status == .rejected {
            self.subject.state.send(.idle)
            return
        }
        guard let result = job.result else { return }
        switch result {
        case .done(let done):
            self.subject.state.send(.done(message: done.text))
        case .confirm(let confirm):
            guard let action = confirm.action else {
                self.subject.state.send(.failed(reason: confirm.text))
                return
            }
            self.subject.state.send(.confirm(command: job.command ?? "", action: action))
        case .failed(let fail):
            self.subject.state.send(.failed(reason: fail.reason))
        }
    }
}


// MARK: - actions

extension AIAgentUsecaseImple {

    public func sendCommand(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.subject.state.send(.processing(command: trimmed))
        self.startProcessing(self.commandUsecase.processCommand(trimmed))
    }

    public func confirm() {
        guard case .confirm(let command, let action) = self.subject.state.value
        else { return }
        self.subject.state.send(.processing(command: command))
        self.startProcessing(self.commandUsecase.processConfirmCommand(action))
    }

    public func decline() {
        if case .confirm(_, let action) = self.subject.state.value {
            self.commandUsecase.rejectConfirmCommand(action)
        }
        self.reset()
    }

    public func reset() {
        self.commandCancellable?.cancel()
        self.commandCancellable = nil
        self.subject.state.send(.idle)
    }

    public func restoreIfNeeded() {
        // 세션 종료 후 복귀 — 영속된 in-flight job에 재연결 (결과는 handleJobResult로 매핑).
        // 영속 job이 없으면 restoreCommandifNeed가 무방출 → idle 유지.
        self.startProcessing(self.commandUsecase.restoreCommandifNeed())
    }

    public func loadUsage() {
        self.usageUsecase.refresh()
    }
}


// MARK: - outputs

extension AIAgentUsecaseImple {

    public var state: AnyPublisher<AIAgentState, Never> {
        return self.subject.state.eraseToAnyPublisher()
    }

    public var usage: AnyPublisher<AIAgentUsage, Never> {
        return self.usageUsecase.currentUsage
    }
}
