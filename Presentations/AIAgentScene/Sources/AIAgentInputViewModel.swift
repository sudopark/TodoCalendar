//
//  AIAgentInputViewModel.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


// MARK: - AIAgentInputState

public enum AIAgentInputState: Equatable, Sendable {
    case voice
    case textInput
    case permissionDenied
}


// MARK: - AIAgentInputViewModelListener

protocol AIAgentInputViewModelListener: AnyObject {
    func aiAgentInput(didComplete text: String)
    func aiAgentInputRequestSystemSetting()
    func aiAgentInput(didFail error: any Error)
}


// MARK: - AIAgentInputViewModel

public protocol AIAgentInputViewModel: AnyObject, Sendable {

    func startInput()
    func stopInput()
    func finishVoiceInput()
    func switchToKeyboard()
    func switchToVoice()
    func submit(_ text: String)
    func openSystemSetting()

    var inputState: AnyPublisher<AIAgentInputState, Never> { get }
    var recognizingText: AnyPublisher<String, Never> { get }
    var inputLevel: AnyPublisher<Float?, Never> { get }
}


// MARK: - AIAgentInputViewModelImple

final class AIAgentInputViewModelImple: AIAgentInputViewModel, @unchecked Sendable {

    private let speechRecognizeUsecase: any SpeechRecognizeUsecase
    weak var listener: (any AIAgentInputViewModelListener)?

    init(speechRecognizeUsecase: any SpeechRecognizeUsecase) {
        self.speechRecognizeUsecase = speechRecognizeUsecase
    }

    private struct Subject {
        let inputState = CurrentValueSubject<AIAgentInputState, Never>(.voice)
    }
    private let subject = Subject()
    private var cancellables = Set<AnyCancellable>()
    private var didBind = false

    private func bindIfNeeded() {
        guard self.didBind == false else { return }
        self.didBind = true

        self.speechRecognizeUsecase.recognizeResult
            .sink(receiveValue: { [weak self] result in
                switch result {
                case .success(let text):
                    self?.listener?.aiAgentInput(didComplete: text)
                case .failure(let error) where error is SpeechRecognizeAuthError:
                    self?.subject.inputState.send(.permissionDenied)
                case .failure(let error):
                    self?.listener?.aiAgentInput(didFail: error)
                }
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - actions

extension AIAgentInputViewModelImple {

    func startInput() {
        self.bindIfNeeded()
        self.subject.inputState.send(.voice)
        self.speechRecognizeUsecase.startListening()
    }

    func stopInput() {
        self.speechRecognizeUsecase.stopListening()
    }

    func finishVoiceInput() {
        self.speechRecognizeUsecase.finishListening()
    }

    func switchToKeyboard() {
        self.speechRecognizeUsecase.stopListening()
        self.subject.inputState.send(.textInput)
    }

    func switchToVoice() {
        self.subject.inputState.send(.voice)
        self.speechRecognizeUsecase.startListening()
    }

    func submit(_ text: String) {
        self.listener?.aiAgentInput(didComplete: text)
    }

    func openSystemSetting() {
        self.listener?.aiAgentInputRequestSystemSetting()
    }
}


// MARK: - outputs

extension AIAgentInputViewModelImple {

    var inputState: AnyPublisher<AIAgentInputState, Never> {
        return self.subject.inputState.removeDuplicates().eraseToAnyPublisher()
    }

    var recognizingText: AnyPublisher<String, Never> {
        return self.speechRecognizeUsecase.recognizingText
    }

    var inputLevel: AnyPublisher<Float?, Never> {
        return self.speechRecognizeUsecase.isRecognizingWithLevel
    }
}
