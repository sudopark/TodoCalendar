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
    var recognizingText: AnyPublisher<String, Never> { get }
    var voiceLevel: AnyPublisher<Float, Never> { get }

    func prepare()
    func enterVoiceInput()
    func finishVoiceInput()
    func enterKeyboardInput()
    func stopInput()
    func submit(_ text: String) throws

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
    private let speechRecognizeUsecase: any SpeechRecognizeUsecase

    public init(
        commandUsecase: any AICommandUsecase,
        usageUsecase: any AIAgentUsageUsecase,
        speechRecognizeUsecase: any SpeechRecognizeUsecase
    ) {
        self.commandUsecase = commandUsecase
        self.usageUsecase = usageUsecase
        self.speechRecognizeUsecase = speechRecognizeUsecase
    }

    private struct Subject {
        let state = CurrentValueSubject<AIAgentState?, Never>(nil)
        let recognizingText = PassthroughSubject<String, Never>()
        let voiceLevel = PassthroughSubject<Float, Never>()
    }
    private let subject = Subject()
    private var commandCancellable: AnyCancellable?
    private var voiceInputBindings = Set<AnyCancellable>()

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


// MARK: - prepare

extension AIAgentOrchestrationUsecaseImple {

    public func prepare() {
        self.restoreIfNeeded()
        self.loadUsage()
    }
}


// MARK: - 입력 제어

extension AIAgentOrchestrationUsecaseImple {

    public func enterVoiceInput() {
        guard self.canEnterVoiceInput else { return }
        self.bindSpeechRecognizing()
        self.speechRecognizeUsecase.startListening()
        self.subject.state.send(.listening(.voice))
    }

    public func finishVoiceInput() {
        self.subject.state.send(.idle)
        self.speechRecognizeUsecase.finishListening()
    }

    public func enterKeyboardInput() {
        guard self.isIdle else { return }
        self.speechRecognizeUsecase.stopListening()
        self.subject.state.send(.listening(.keyboard))
    }

    public func stopInput() {
        self.resetVoiceBinding()
        self.speechRecognizeUsecase.stopListening()
        self.subject.state.send(.idle)
    }

    private func bindSpeechRecognizing() {
        self.resetVoiceBinding()

        self.speechRecognizeUsecase.recognizeResult
            .sink { [weak self] result in
                switch result {
                case .success(let text):
                    self?.resetVoiceBinding()
                    self?.subject.state.send(.idle)
                    try? self?.submit(text)
                case .failure(let error):
                    self?.handleRecognizeFailed(error)
                }
            }
            .store(in: &self.voiceInputBindings)

        self.speechRecognizeUsecase.recognizingText
            .sink { [weak self] text in
                self?.subject.recognizingText.send(text)
            }
            .store(in: &self.voiceInputBindings)

        self.speechRecognizeUsecase.isRecognizingWithLevel
            .compactMap { $0 }
            .sink { [weak self] level in
                self?.subject.voiceLevel.send(level)
            }
            .store(in: &self.voiceInputBindings)
    }

    private func handleRecognizeFailed(_ error: any Error) {
        self.subject.state.send(.idle)
    }

    private func resetVoiceBinding() {
        self.voiceInputBindings.forEach { $0.cancel() }
        self.voiceInputBindings.removeAll()
    }
}


// MARK: - submit / command actions

extension AIAgentOrchestrationUsecaseImple {

    public func submit(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RuntimeError(key: "AIAgent.emptyCommand", "command text is empty")
        }
        guard self.isIdle else {
            throw RuntimeError(key: "AIAgent.busy", "already processing a command")
        }
        self.subject.state.send(.processing(command: trimmed))
        self.startProcessing(self.commandUsecase.processCommand(trimmed))
    }

    private var isIdle: Bool {
        switch self.subject.state.value {
        case .none, .idle: return true
        default: return false
        }
    }

    private var canEnterVoiceInput: Bool {
        switch self.subject.state.value {
        case .none, .idle, .listening(.keyboard): return true
        default: return false
        }
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

    public var recognizingText: AnyPublisher<String, Never> {
        return self.subject.recognizingText.eraseToAnyPublisher()
    }

    public var voiceLevel: AnyPublisher<Float, Never> {
        return self.subject.voiceLevel.eraseToAnyPublisher()
    }
}
