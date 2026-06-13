//
//  AIAgentUsecase.swift
//  Domain
//
//  Created by sudo.park on 6/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


// MARK: - AIAgentUsecase

public protocol AIAgentUsecase: AnyObject, Sendable {

    var state: AnyPublisher<AIAgentState, Never> { get }
    var usage: AnyPublisher<AIAgentUsage, Never> { get }

    func startVoiceInput()
    func finishVoiceInput()
    func switchToKeyboard()
    func switchToVoice()
    func submitText(_ text: String)

    func confirm()
    func decline()

    func reset()
    func restoreIfNeeded()
    func loadUsage()
}


// MARK: - AIAgentUsecaseImple

public final class AIAgentUsecaseImple: AIAgentUsecase, @unchecked Sendable {

    private let speechUsecase: any SpeechRecognizeUsecase
    private let commandUsecase: any AICommandUsecase
    private let usageUsecase: any AIAgentUsageUsecase

    public init(
        speechUsecase: any SpeechRecognizeUsecase,
        commandUsecase: any AICommandUsecase,
        usageUsecase: any AIAgentUsageUsecase
    ) {
        self.speechUsecase = speechUsecase
        self.commandUsecase = commandUsecase
        self.usageUsecase = usageUsecase

        self.bindSpeech()
    }

    private struct Subject {
        let state = CurrentValueSubject<AIAgentState, Never>(.idle)
    }
    private let subject = Subject()
    private var cancelBag = Set<AnyCancellable>()
    private var commandCancellable: AnyCancellable?
    private var currentCommandText: String?

    private func bindSpeech() {

        // 음성 usecase는 권한 요청 Task 등에서 메인 외 스레드로 방출할 수 있다.
        // 상태/in-flight 핸들을 메인 UI 액션(confirm/reset)과 직렬화하기 위해 메인으로 수신한다.
        Publishers.CombineLatest(
            self.speechUsecase.recognizingText,
            self.speechUsecase.isRecognizingWithLevel
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { [weak self] text, level in
            self?.updateVoiceState(text: text, level: level)
        })
        .store(in: &self.cancelBag)

        self.speechUsecase.recognizeResult
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let text):
                    self.handleVoiceRecognized(text)
                case .failure(let error):
                    self.handleVoiceFailure(error)
                }
            })
            .store(in: &self.cancelBag)
    }

    private func handleVoiceRecognized(_ text: String) {
        // 음성 입력 단계에서 온 결과만 처리로 넘긴다.
        // (이미 processing/confirm 등으로 넘어간 뒤 도착한 늦은 결과가 in-flight job을 덮어쓰지 않도록)
        switch self.subject.state.value {
        case .listening, .recognizing:
            self.submitText(text)
        default:
            break
        }
    }

    private func updateVoiceState(text: String, level: Float?) {
        switch self.subject.state.value {
        case .idle, .listening, .recognizing:
            guard level != nil else { return }
            let next: AIAgentState = text.isEmpty
                ? .listening(level: level)
                : .recognizing(text: text, level: level)
            self.subject.state.send(next)
        default:
            break
        }
    }

    private func handleVoiceFailure(_ error: any Error) {
        if error is SpeechRecognizeAuthError {
            self.subject.state.send(.voicePermissionDenied)
        } else {
            self.subject.state.send(.failed(reason: nil))
        }
    }

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
        guard job.isFinish, let result = job.result else { return }
        switch result {
        case .done(let done):
            self.subject.state.send(.done(message: done.text))
        case .confirm(let confirm):
            let command = job.command ?? self.currentCommandText ?? ""
            guard let action = confirm.action else {
                self.subject.state.send(.failed(reason: confirm.text))
                return
            }
            self.subject.state.send(.confirm(command: command, action: action))
        case .failed(let fail):
            self.subject.state.send(.failed(reason: fail.reason))
        }
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


// MARK: - actions

extension AIAgentUsecaseImple {

    public func startVoiceInput() {
        self.subject.state.send(.listening(level: nil))
        self.speechUsecase.startListening()
    }

    public func finishVoiceInput() {
        self.speechUsecase.finishListening()
    }

    public func switchToKeyboard() {
        self.speechUsecase.stopListening()
        self.subject.state.send(.textInput(text: ""))
    }

    public func switchToVoice() {
        self.startVoiceInput()
    }

    public func submitText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.currentCommandText = trimmed
        self.subject.state.send(.processing(command: trimmed))
        self.startProcessing(self.commandUsecase.processCommand(trimmed))
    }

    public func confirm() {
        guard case .confirm(let command, let action) = self.subject.state.value
        else { return }
        self.currentCommandText = command
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
        self.speechUsecase.stopListening()
        self.currentCommandText = nil
        self.subject.state.send(.idle)
    }

    public func restoreIfNeeded() {
        // 같은 세션 holder 보유 상태 재방출. 앱 완전 종료 후 복원은 범위 밖.
        self.subject.state.send(self.subject.state.value)
    }

    public func loadUsage() {
        self.usageUsecase.refresh()
    }
}
