//
//  AIAgentOrchestrationUsecase.swift
//  Domain
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


// MARK: - AIAgentOrchestrationUsecase

public protocol AIAgentOrchestrationUsecase: AnyObject, Sendable {

    var state: AnyPublisher<AIAgentState, Never> { get }
    var usage: AnyPublisher<AIAgentUsage, Never> { get }

    func sendCommand(_ text: String)
    func confirm()
    func decline()

    func reset()
    func restoreIfNeeded()
    func loadUsage()
}


// MARK: - AIAgentOrchestrationUsecaseImple

public final class AIAgentOrchestrationUsecaseImple: AIAgentOrchestrationUsecase, @unchecked Sendable {

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
        let state = CurrentValueSubject<AIAgentState?, Never>(nil)
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
            self.subject.state.send(
                .confirm(command: job.command ?? "", message: confirm.text, action: action)
            )
        case .failed(let fail):
            self.subject.state.send(.failed(reason: fail.reason))
        }
    }
}


// MARK: - actions

extension AIAgentOrchestrationUsecaseImple {

    public func sendCommand(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.subject.state.send(.processing(command: trimmed))
        self.startProcessing(self.commandUsecase.processCommand(trimmed))
    }

    public func confirm() {
        guard case .confirm(let command, _, let action) = self.subject.state.value ?? .idle
        else { return }
        self.subject.state.send(.processing(command: command))
        self.startProcessing(self.commandUsecase.processConfirmCommand(action))
    }

    public func decline() {
        if case .confirm(_, _, let action) = self.subject.state.value ?? .idle {
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
        self.commandCancellable?.cancel()
        self.commandCancellable = self.commandUsecase.restoreCommandifNeed()
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.subject.state.send(.failed(reason: nil))
                    }
                },
                receiveValue: { [weak self] job in
                    guard let self else { return }
                    if let job {
                        self.handleJobResult(job)
                    } else {
                        self.subject.state.send(.idle)
                    }
                }
            )
    }

    public func loadUsage() {
        self.usageUsecase.refresh()
    }
}


// MARK: - outputs

extension AIAgentOrchestrationUsecaseImple {

    public var state: AnyPublisher<AIAgentState, Never> {
        return self.subject.state.compactMap { $0 }.eraseToAnyPublisher()
    }

    public var usage: AnyPublisher<AIAgentUsage, Never> {
        return self.usageUsecase.currentUsage
    }
}
